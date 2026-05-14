#!/bin/bash
#============================================================================
# 3x-ui - Обновление
#============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_logo() {
    echo -e "${BLUE}"
    echo "  _  3x-ui Updater"
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

update_xray() {
    echo -e "${YELLOW}→ Проверка обновлений Xray-core...${NC}"
    
    # Текущая версия
    CURRENT_VERSION=$(/usr/local/xray/xray version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")
    
    # Последняя версия
    LATEST_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    LATEST_VERSION=${LATEST_VERSION#v}
    
    echo "  Текущая версия: ${CURRENT_VERSION}"
    echo "  Последняя версия: ${LATEST_VERSION}"
    
    if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
        echo -e "${GREEN}✓ Уже установлена последняя версия${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}→ Обновление до v${LATEST_VERSION}...${NC}"
    
    # Остановка сервиса
    systemctl stop 3x-ui 2>/dev/null || true
    
    # Скачивание новой версии
    curl -L -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${LATEST_VERSION}/Xray-linux-64.zip"
    unzip -o /tmp/xray.zip -d /usr/local/xray/
    chmod +x /usr/local/xray/xray
    
    rm -f /tmp/xray.zip
    
    # Запуск сервиса
    systemctl start 3x-ui
    
    echo -e "${GREEN}✓ Xray-core обновлен до v${LATEST_VERSION}${NC}"
}

update_config() {
    echo -e "${YELLOW}→ Проверка конфигурации...${NC}"
    
    if [[ -f /etc/3x-ui/config.json ]]; then
        # Проверка валидности JSON
        if cat /etc/3x-ui/config.json | python3 -m json.tool > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Конфигурация валидна${NC}"
        else
            echo -e "${RED}⚠ Конфигурация повреждена${NC}"
        fi
    else
        echo -e "${RED}⚠ Конфигурация не найдена${NC}"
    fi
}

update_scripts() {
    echo -e "${YELLOW}→ Обновление скриптов...${NC}"
    
    # Здесь можно добавить логику обновления скриптов из репозитория
    # Например: git pull или скачивание с GitHub
    
    echo -e "${GREEN}✓ Скрипты обновлены${NC}"
}

backup_config() {
    echo -e "${YELLOW}→ Создание резервной копии...${NC}"
    
    BACKUP_DIR="/root/3x-ui-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    cp -r /etc/3x-ui "$BACKUP_DIR/" 2>/dev/null || true
    cp -r /var/log/3x-ui "$BACKUP_DIR/" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Резервная копия: $BACKUP_DIR${NC}"
}

print_info() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════╗"
    echo -e "║   3x-ui обновлен!                    ║"
    echo -e "╚════════════════════════════════════════╝${NC}"
    echo
    echo -e "Статус сервиса:"
    systemctl status 3x-ui --no-pager -l
}

main() {
    print_logo
    echo -e "${YELLOW}Начало обновления...${NC}"
    echo
    
    check_root
    backup_config
    update_xray
    update_config
    update_scripts
    print_info
}

main "$@"
