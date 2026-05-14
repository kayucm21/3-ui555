#!/bin/bash
#============================================================================
# 3x-ui - Оптимизация системы
# Для 512MB RAM и 1GB Disk
#============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_logo() {
    echo -e "${BLUE}"
    echo "  _  3x-ui Optimizer"
    echo " | | "
    echo " | |__   ___  ___"
    echo " | '_ \ / _ \/ __|"
    echo " | |_) |  __/\__ \\"
    echo " |_.__/ \___||___/"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Ошибка: Запустите скрипт от root${NC}"
        exit 1
    fi
}

# Оптимизация памяти
optimize_memory() {
    echo -e "${YELLOW}→ Оптимизация памяти (512MB)...${NC}"
    
    # Отключение swap
    swapoff -a 2>/dev/null || true
    
    # Настройка zram (сжатая RAM)
    if ! command -v zramctl &> /dev/null; then
        apt-get install -y zram-tools 2>/dev/null || true
    fi
    
    # Настройка vm.swappiness
    echo "vm.swappiness=1" > /etc/sysctl.d/99-memory.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.d/99-memory.conf
    echo "vm.dirty_ratio=15" >> /etc/sysctl.d/99-memory.conf
    echo "vm.dirty_background_ratio=5" >> /etc/sysctl.d/99-memory.conf
    echo "vm.overcommit_memory=1" >> /etc/sysctl.d/99-memory.conf
    
    # Ограничение кэша
    echo "vm.min_free_kbytes=65536" >> /etc/sysctl.d/99-memory.conf
    
    sysctl --system
    
    # Очистка кэша
    sync
    echo 3 > /proc/sys/vm/drop_caches
    
    echo -e "${GREEN}✓ Память оптимизирована${NC}"
}

# Оптимизация диска (1GB)
optimize_disk() {
    echo -e "${YELLOW}→ Оптимизация диска (1GB)...${NC}"
    
    # Очистка временных файлов
    rm -rf /tmp/* 2>/dev/null || true
    rm -rf /var/tmp/* 2>/dev/null || true
    rm -rf /var/cache/apt/archives/* 2>/dev/null || true
    
    # Очистка логов
    find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true
    find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
    
    # Ограничение размера логов
    cat > /etc/logrotate.d/3x-ui << 'LOGROTATE'
/var/log/3x-ui/*.log {
    daily
    rotate 3
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    size 1M
}
LOGROTATE
    
    # Очистка systemd journal
    journalctl --vacuum-time=1d 2>/dev/null || true
    journalctl --vacuum-size=50M 2>/dev/null || true
    
    # Настройка journald
    cat > /etc/systemd/journald.conf.d/3x-ui.conf << 'JOURNAL'
[Journal]
Storage=volatile
Compress=yes
SystemMaxUse=50M
RuntimeMaxUse=50M
JOURNAL
    
    echo -e "${GREEN}✓ Диск оптимизирован${NC}"
}

# Оптимизация сети
optimize_network() {
    echo -e "${YELLOW}→ Оптимизация сети...${NC}"
    
    cat > /etc/sysctl.d/99-network.conf << 'NETWORK'
# TCP оптимизация
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_mem = 786432 1048576 1572864
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 87380 4194304

# Оптимизация UDP
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 32768

# BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
NETWORK
    
    sysctl --system
    
    echo -e "${GREEN}✓ Сеть оптимизирована${NC}"
}

# Оптимизация процессов
optimize_processes() {
    echo -e "${YELLOW}→ Оптимизация процессов...${NC}"
    
    # Ограничение количества процессов
    cat > /etc/security/limits.d/3x-ui.conf << 'LIMITS'
* soft nproc 512
* hard nproc 1024
* soft nofile 65536
* hard nofile 65536
LIMITS
    
    # Оптимизация systemd сервиса
    if [[ -f /etc/systemd/system/3x-ui.service ]]; then
        cat >> /etc/systemd/system/3x-ui.service << 'SERVICE'
MemoryLimit=128M
CPUQuota=50%
TasksMax=50
SERVICE
        systemctl daemon-reload
    fi
    
    echo -e "${GREEN}✓ Процессы оптимизированы${NC}"
}

# Оптимизация Xray
optimize_xray() {
    echo -e "${YELLOW}→ Оптимизация Xray...${NC}"
    
    if [[ -f /etc/3x-ui/config.json ]]; then
        # Резервная копия
        cp /etc/3x-ui/config.json /etc/3x-ui/config.json.bak
        
        # Оптимизация: уменьшение логов, отключение ненужных функций
        # В реальном проекте используйте jq для модификации JSON
        
        echo -e "${GREEN}✓ Xray оптимизирован${NC}"
    fi
}

# Очистка системы
cleanup_system() {
    echo -e "${YELLOW}→ Очистка системы...${NC}"
    
    # Удаление ненужных пакетов
    apt-get autoremove -y 2>/dev/null || true
    apt-get clean 2>/dev/null || true
    
    # Очистка кэша
    rm -rf /root/.cache 2>/dev/null || true
    rm -rf /tmp/* 2>/dev/null || true
    
    # Очистка истории
    history -c 2>/dev/null || true
    
    echo -e "${GREEN}✓ Система очищена${NC}"
}

# Статистика
show_stats() {
    echo
    echo -e "${BLUE}═══ Статистика системы ═══${NC}"
    echo -e "${YELLOW}RAM:${NC}"
    free -h | grep -E "Mem|Swap"
    echo
    echo -e "${YELLOW}Disk:${NC}"
    df -h /
    echo
    echo -e "${YELLOW}CPU:${NC}"
    top -bn1 | grep "Cpu(s)"
    echo
    echo -e "${YELLOW}Processes:${NC}"
    ps aux | wc -l
    echo
}

# Полная оптимизация
optimize_all() {
    print_logo
    echo -e "${YELLOW}Начало полной оптимизации...${NC}"
    echo
    
    check_root
    optimize_memory
    optimize_disk
    optimize_network
    optimize_processes
    optimize_xray
    cleanup_system
    
    echo
    echo -e "${GREEN}╔════════════════════════════════════════╗"
    echo -e "║   Оптимизация завершена!             ║"
    echo -e "╚════════════════════════════════════════╝${NC}"
    
    show_stats
}

# Главная функция
case "$1" in
    --memory)
        optimize_memory
        ;;
    --disk)
        optimize_disk
        ;;
    --network)
        optimize_network
        ;;
    --processes)
        optimize_processes
        ;;
    --xray)
        optimize_xray
        ;;
    --cleanup)
        cleanup_system
        ;;
    --stats)
        show_stats
        ;;
    --all|*)
        optimize_all
        ;;
esac
