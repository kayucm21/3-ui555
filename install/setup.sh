#!/bin/bash
#============================================================================
# 3x-ui - Быстрая настройка (One-liner)
#============================================================================

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════╗"
echo "║         3x-ui Quick Setup                  ║"
echo "║  Оптимизировано для 512MB RAM / 1GB Disk  ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"

# Проверка root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ошибка: Запустите от root${NC}"
    exit 1
fi

# Скачивание скриптов
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo -e "${YELLOW}→ Скачивание скриптов...${NC}"

# Скачивание с GitHub
REPO="https://raw.githubusercontent.com/kayucm21/3x-ui2011/main"

curl -sL "$REPO/install/install.sh" -o install.sh
curl -sL "$REPO/install/update.sh" -o update.sh
curl -sL "$REPO/install/uninstall.sh" -o uninstall.sh
curl -sL "$REPO/scripts/generate_client.sh" -o generate_client.sh
curl -sL "$REPO/scripts/discord_notify.sh" -o discord_notify.sh
curl -sL "$REPO/scripts/optimize.sh" -o optimize.sh

chmod +x *.sh

echo -e "${GREEN}✓ Скрипты скачаны${NC}"

# Запуск установки
echo -e "${YELLOW}→ Запуск установки...${NC}"
bash install.sh

# Очистка
cd /
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✓ Настройка завершена!${NC}"
