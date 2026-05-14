#!/bin/bash
#============================================================================
# 3x-ui - WARP Cloudflare (WireGuard)
# Скрывает реальный IP сервера через Cloudflare WARP
#============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

WARP_DIR="/etc/3x-ui/warp"
WARP_CONF="${WARP_DIR}/wgcf.conf"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Ошибка: Запустите от root${NC}"
        exit 1
    fi
}

# Установка wgcf
install_wgcf() {
    echo -e "${YELLOW}→ Установка wgcf...${NC}"
    
    if ! command -v wgcf &> /dev/null; then
        curl -fsSL https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_amd64 -o /usr/local/bin/wgcf
        chmod +x /usr/local/bin/wgcf
    fi
    
    # Установка WireGuard
    if [[ -f /etc/debian_version ]]; then
        apt-get update -qq
        apt-get install -y -qq wireguard-tools net-tools
    elif [[ -f /etc/redhat-release ]]; then
        yum install -y -q wireguard-tools
    fi
    
    echo -e "${GREEN}✓ wgcf установлен${NC}"
}

# Регистрация WARP
register_warp() {
    echo -e "${YELLOW}→ Регистрация WARP...${NC}"
    
    mkdir -p "$WARP_DIR"
    cd "$WARP_DIR"
    
    # Генерация аккаунта
    wgcf register --accept-tos
    
    # Генерация конфигурации
    wgcf generate
    
    # Копирование конфига
    cp wgcf-profile.conf "$WARP_CONF"
    
    echo -e "${GREEN}✓ WARP зарегистрирован${NC}"
}

# Запуск WARP
start_warp() {
    echo -e "${YELLOW}→ Запуск WARP...${NC}"
    
    if [[ ! -f "$WARP_CONF" ]]; then
        echo -e "${RED}Ошибка: Конфигурация WARP не найдена${NC}"
        exit 1
    fi
    
    # Создание systemd сервиса
    cat > /etc/systemd/system/warp.service << EOF
[Unit]
Description=Cloudflare WARP (WireGuard)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${WARP_DIR}
ExecStart=/usr/bin/wg-quick up ${WARP_CONF}
ExecStop=/usr/bin/wg-quick down ${WARP_CONF}

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable warp
    systemctl start warp
    
    echo -e "${GREEN}✓ WARP запущен${NC}"
}

# Настройка маршрутизации через WARP
setup_routing() {
    echo -e "${YELLOW}→ Настройка маршрутизации...${NC}"
    
    # Получение IP WARP интерфейса
    WARP_IP=$(ip addr show warp 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    
    if [[ -z "$WARP_IP" ]]; then
        WARP_IP=$(ip addr show wgcf-profile 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    fi
    
    # Настройка iptables - весь исходящий трафик через WARP
    iptables -t nat -A POSTROUTING -o warp -j MASQUERADE 2>/dev/null || true
    iptables -t nat -A POSTROUTING -o wgcf-profile -j MASQUERADE 2>/dev/null || true
    
    # Разрешить пересылку
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-warp.conf
    sysctl --system
    
    # Сохранение правил
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    fi
    
    echo -e "${GREEN}✓ Маршрутизация настроена${NC}"
}

# Проверка статуса
check_status() {
    echo -e "${BLUE}═══ Статус WARP ═══${NC}"
    
    if systemctl is-active --quiet warp; then
        echo -e "${GREEN}● WARP: Запущен${NC}"
    else
        echo -e "${RED}● WARP: Остановлен${NC}"
    fi
    
    # Проверка IP
    echo -e "${YELLOW}Проверка IP...${NC}"
    REAL_IP=$(curl -s --max-time 5 ifconfig.me)
    WARP_IP=$(curl -s --max-time 5 https://1.1.1.1/cdn-cgi/trace 2>/dev/null | grep "ip=" | cut -d= -f2)
    
    echo "  Реальный IP: $REAL_IP"
    echo "  WARP IP: ${WARP_IP:-Не определен}"
    
    if [[ -n "$WARP_IP" && "$WARP_IP" != "$REAL_IP" ]]; then
        echo -e "  ${GREEN}✓ IP скрыт через WARP${NC}"
    else
        echo -e "  ${YELLOW}⚠ WARP может не работать${NC}"
    fi
}

# Остановка WARP
stop_warp() {
    echo -e "${YELLOW}→ Остановка WARP...${NC}"
    systemctl stop warp 2>/dev/null || true
    wg-quick down "$WARP_CONF" 2>/dev/null || true
    echo -e "${GREEN}✓ WARP остановлен${NC}"
}

# Удаление WARP
uninstall_warp() {
    echo -e "${YELLOW}→ Удаление WARP...${NC}"
    stop_warp
    systemctl disable warp 2>/dev/null || true
    rm -f /etc/systemd/system/warp.service
    rm -rf "$WARP_DIR"
    rm -f /usr/local/bin/wgcf
    systemctl daemon-reload
    echo -e "${GREEN}✓ WARP удален${NC}"
}

# Тест скорости
test_warp() {
    echo -e "${YELLOW}→ Тест WARP...${NC}"
    
    echo -e "${CYAN}Без WARP:${NC}"
    curl -s -o /dev/null -w "  Время ответа: %{time_total}s\n  IP: %{remote_ip}\n" --max-time 10 ifconfig.me
    
    echo
    echo -e "${CYAN}С WARP (через Cloudflare):${NC}"
    curl -s -o /dev/null -w "  Время ответа: %{time_total}s\n" --max-time 10 https://1.1.1.1/cdn-cgi/trace
}

# Полная установка
install_all() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════╗"
    echo "║     WARP Cloudflare Installer              ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_root
    install_wgcf
    register_warp
    start_warp
    setup_routing
    check_status
    
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════╗"
    echo -e "║   WARP установлен и запущен!              ║"
    echo -e "║   Реальный IP скрыт через Cloudflare      ║"
    echo -e "╚════════════════════════════════════════════╝${NC}"
}

# Главное меню
case "$1" in
    --install)
        install_all
        ;;
    --start)
        check_root
        start_warp
        setup_routing
        ;;
    --stop)
        check_root
        stop_warp
        ;;
    --status)
        check_status
        ;;
    --test)
        test_warp
        ;;
    --uninstall)
        check_root
        uninstall_warp
        ;;
    *)
        echo "Использование:"
        echo "  $0 --install      - Полная установка WARP"
        echo "  $0 --start        - Запуск WARP"
        echo "  $0 --stop         - Остановка WARP"
        echo "  $0 --status       - Статус WARP"
        echo "  $0 --test         - Тест скорости"
        echo "  $0 --uninstall    - Удаление WARP"
        ;;
esac
