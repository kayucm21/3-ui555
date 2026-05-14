#!/bin/bash
#============================================================================
# 3x-ui - Мониторинг системы
#============================================================================

CONFIG_FILE="/etc/3x-ui/monitor.conf"
DISCORD_SCRIPT="/etc/3x-ui/discord_notify.sh"

# Загрузка конфигурации
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
    
    # Значения по умолчанию
    CPU_THRESHOLD="${CPU_THRESHOLD:-80}"
    RAM_THRESHOLD="${RAM_THRESHOLD:-90}"
    DISK_THRESHOLD="${DISK_THRESHOLD:-85}"
    CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
}

# Проверка CPU
check_cpu() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    cpu_usage=${cpu_usage%.*}
    
    if [[ "$cpu_usage" -gt "$CPU_THRESHOLD" ]]; then
        echo "⚠️ Высокая загрузка CPU: ${cpu_usage}%"
        send_alert "CPU Alert" "Загрузка CPU: ${cpu_usage}% (порог: ${CPU_THRESHOLD}%)"
    fi
}

# Проверка RAM
check_ram() {
    local ram_info=$(free | grep Mem)
    local total=$(echo "$ram_info" | awk '{print $2}')
    local used=$(echo "$ram_info" | awk '{print $3}')
    local ram_usage=$((used * 100 / total))
    
    if [[ "$ram_usage" -gt "$RAM_THRESHOLD" ]]; then
        echo "⚠️ Высокая загрузка RAM: ${ram_usage}%"
        send_alert "RAM Alert" "Загрузка RAM: ${ram_usage}% (порог: ${RAM_THRESHOLD}%)"
    fi
}

# Проверка диска
check_disk() {
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    
    if [[ "$disk_usage" -gt "$DISK_THRESHOLD" ]]; then
        echo "⚠️ Высокая загрузка диска: ${disk_usage}%"
        send_alert "Disk Alert" "Загрузка диска: ${disk_usage}% (порог: ${DISK_THRESHOLD}%)"
    fi
}

# Проверка сервиса
check_service() {
    if ! systemctl is-active --quiet 3x-ui; then
        echo "⚠️ Сервис 3x-ui не запущен!"
        send_alert "Service Alert" "Сервис 3x-ui не запущен! Перезапуск..."
        systemctl restart 3x-ui
    fi
}

# Отправка уведомления
send_alert() {
    local title="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # В консоль
    echo "[${timestamp}] ${title}: ${message}"
    
    # В Discord
    if [[ -f "$DISCORD_SCRIPT" ]]; then
        bash "$DISCORD_SCRIPT" --error "${title}: ${message}"
    fi
    
    # В лог
    echo "[${timestamp}] ${title}: ${message}" >> /var/log/3x-ui/monitor.log
}

# Статус системы
show_status() {
    echo "═══════════════════════════════════════"
    echo "          Статус системы"
    echo "═══════════════════════════════════════"
    
    # CPU
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo "CPU: ${cpu}%"
    
    # RAM
    local ram_info=$(free -h | grep Mem)
    echo "RAM: $(echo "$ram_info" | awk '{print $3}') / $(echo "$ram_info" | awk '{print $2}')"
    
    # Disk
    echo "Disk: $(df -h / | awk 'NR==2 {print $3}') / $(df -h / | awk 'NR==2 {print $2}')"
    
    # Uptime
    echo "Uptime: $(uptime -p)"
    
    # Сервис
    if systemctl is-active --quiet 3x-ui; then
        echo "3x-ui: 🟢 Запущен"
    else
        echo "3x-ui: 🔴 Остановлен"
    fi
    
    # Подключения
    local connections=$(ss -tun | wc -l)
    echo "Подключения: $connections"
    
    echo "═══════════════════════════════════════"
}

# Настройка мониторинга
setup_monitoring() {
    echo "Настройка мониторинга..."
    
    read -p "Порог CPU (по умолчанию 80): " cpu
    read -p "Порог RAM (по умолчанию 90): " ram
    read -p "Порог Disk (по умолчанию 85): " disk
    
    cat > "$CONFIG_FILE" << EOF
CPU_THRESHOLD=${cpu:-80}
RAM_THRESHOLD=${ram:-90}
DISK_THRESHOLD=${disk:-85}
CHECK_INTERVAL=60
EOF
    
    echo "✓ Конфигурация сохранена"
}

# Цикл мониторинга
monitor_loop() {
    load_config
    
    while true; do
        check_cpu
        check_ram
        check_disk
        check_service
        
        sleep "$CHECK_INTERVAL"
    done
}

# Главная функция
case "$1" in
    --status)
        show_status
        ;;
    --setup)
        setup_monitoring
        ;;
    --once)
        load_config
        check_cpu
        check_ram
        check_disk
        check_service
        ;;
    --loop|*)
        monitor_loop
        ;;
esac
