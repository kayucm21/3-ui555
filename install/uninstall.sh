#!/bin/bash
#============================================================================
# 3x-ui - Полное удаление
#============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_logo() {
    echo -e "${RED}"
    echo "  _  3x-ui Uninstaller"
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

confirm() {
    echo -e "${RED}⚠ ВНИМАНИЕ: Это действие удалит 3x-ui полностью!${NC}"
    read -p "Вы уверены? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}Отмена${NC}"
        exit 0
    fi
}

stop_service() {
    echo -e "${YELLOW}→ Остановка сервисов...${NC}"
    systemctl stop 3x-ui 2>/dev/null || true
    systemctl stop 3x-ui-web 2>/dev/null || true
    systemctl disable 3x-ui 2>/dev/null || true
    systemctl disable 3x-ui-web 2>/dev/null || true
    rm -f /etc/systemd/system/3x-ui.service
    rm -f /etc/systemd/system/3x-ui-web.service
    systemctl daemon-reload
    echo -e "${GREEN}✓ Сервисы остановлены${NC}"
}

remove_xray() {
    echo -e "${YELLOW}→ Удаление Xray-core...${NC}"
    rm -rf /usr/local/xray
    echo -e "${GREEN}✓ Xray-core удален${NC}"
}

remove_config() {
    echo -e "${YELLOW}→ Удаление конфигурации...${NC}"
    rm -rf /etc/3x-ui
    rm -rf /var/log/3x-ui
    echo -e "${GREEN}✓ Конфигурация удалена${NC}"
}

remove_firewall_rules() {
    echo -e "${YELLOW}→ Удаление правил firewall...${NC}"
    iptables -D INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
    iptables -D INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
    iptables -D INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
    iptables -D INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
    
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    elif command -v iptables-save &> /dev/null; then
        iptables-save > /etc/iptables/rules.v4
    fi
    
    echo -e "${GREEN}✓ Правила firewall удалены${NC}"
}

remove_dns() {
    echo -e "${YELLOW}→ Восстановление DNS...${NC}"
    chattr -i /etc/resolv.conf 2>/dev/null || true
    if [[ -f /etc/resolv.conf.bak ]]; then
        mv /etc/resolv.conf.bak /etc/resolv.conf
    fi
    echo -e "${GREEN}✓ DNS восстановлен${NC}"
}

remove_cron() {
    echo -e "${YELLOW}→ Удаление cron задач...${NC}"
    crontab -l 2>/dev/null | grep -v "discord_notify" | crontab - 2>/dev/null || true
    echo -e "${GREEN}✓ Cron задачи удалены${NC}"
}

print_info() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════╗"
    echo -e "║   3x-ui полностью удален!            ║"
    echo -e "╚════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Удалены:${NC}"
    echo "  ✓ Сервис 3x-ui"
    echo "  ✓ Xray-core"
    echo "  ✓ Конфигурация"
    echo "  ✓ Логи"
    echo "  ✓ Firewall правила"
    echo
    echo -e "${GREEN}✓ Удаление завершено!${NC}"
}

main() {
    print_logo
    echo
    
    check_root
    confirm
    echo
    stop_service
    remove_xray
    remove_config
    remove_firewall_rules
    remove_dns
    remove_cron
    print_info
}

main "$@"
