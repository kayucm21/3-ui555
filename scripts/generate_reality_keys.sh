#!/bin/bash
#============================================================================
# 3x-ui - Генерация Reality ключей
#============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════╗"
echo "║     Reality Key Generator                  ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"

# Проверка наличия xray
if ! command -v /usr/local/xray/xray &> /dev/null; then
    echo -e "${RED}Ошибка: Xray не установлен${NC}"
    exit 1
fi

# Генерация ключей
echo -e "${YELLOW}→ Генерация Reality ключей...${NC}"

# Генерация x25519 ключей
KEYS=$(/usr/local/xray/xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "Private" | cut -d: -f2 | tr -d ' ')
PUBLIC_KEY=$(echo "$KEYS" | grep "Public" | cut -d: -f2 | tr -d ' ')

# Генерация shortId
SHORT_ID=$(openssl rand -hex 8 2>/dev/null || cat /dev/urandom | tr -dc 'a-f0-9' | head -c 16)

# Вывод
echo
echo -e "${GREEN}═══ Reality Configuration ═══${NC}"
echo
echo -e "${YELLOW}Private Key:${NC}"
echo "  $PRIVATE_KEY"
echo
echo -e "${YELLOW}Public Key (для клиента):${NC}"
echo "  $PUBLIC_KEY"
echo
echo -e "${YELLOW}Short ID:${NC}"
echo "  $SHORT_ID"
echo
echo -e "${BLUE}═══ Пример конфигурации клиента ═══${NC}"
echo "  pbk: $PUBLIC_KEY"
echo "  sid: $SHORT_ID"
echo "  sni: google.com"
echo

# Сохранение в файл
CONFIG_FILE="/etc/3x-ui/reality_keys.txt"
mkdir -p /etc/3x-ui

cat > "$CONFIG_FILE" << EOF
Reality Keys
Generated: $(date)

Private Key: $PRIVATE_KEY
Public Key: $PUBLIC_KEY
Short ID: $SHORT_ID
EOF

echo -e "${GREEN}✓ Ключи сохранены в: $CONFIG_FILE${NC}"
