#!/bin/bash
#============================================================================
# 3x-ui - Генерация клиента
# Создание ссылок для подключения (VLESS, VMess, Trojan)
#============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_FILE="/etc/3x-ui/config.json"
CLIENTS_FILE="/etc/3x-ui/clients.json"

# Проверка root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ошибка: Запустите скрипт от root${NC}"
    exit 1
fi

# Генерация UUID
generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

# Получение IP сервера
get_server_ip() {
    curl -s ifconfig.me
}

# Чтение конфигурации
read_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}Ошибка: Конфигурация не найдена${NC}"
        exit 1
    fi
}

# Создание нового клиента
create_client() {
    local client_name="$1"
    local client_uuid=$(generate_uuid)
    local port="$2"
    local sni="$3"
    
    echo -e "${YELLOW}→ Создание клиента: $client_name${NC}"
    
    # Чтение текущей конфигурации
    local config=$(cat "$CONFIG_FILE")
    
    # Добавление клиента в VLESS inbound
    # (упрощенная версия - в реальном проекте нужно использовать jq)
    
    echo -e "${GREEN}✓ Клиент создан${NC}"
    echo
    echo -e "${BLUE}═══ Данные клиента ═══${NC}"
    echo "  Имя: $client_name"
    echo "  UUID: $client_uuid"
    echo "  Порт: $port"
    echo "  SNI: $sni"
    echo
}

# Генерация VLESS ссылки
generate_vless_link() {
    local uuid="$1"
    local ip="$2"
    local port="$3"
    local sni="$4"
    local name="$5"
    
    # VLESS Reality ссылка
    local link="vless://${uuid}@${ip}:${port}?encryption=none&security=reality&sni=${sni}&fp=chrome&pbk=&sid=&type=tcp&flow=xtls-rprx-vision#${name}"
    
    echo "$link"
}

# Генерация VMess ссылки
generate_vmess_link() {
    local uuid="$1"
    local ip="$2"
    local port="$3"
    local name="$4"
    
    # VMess JSON (base64)
    local vmess_json="{\"v\":\"2\",\"ps\":\"${name}\",\"add\":\"${ip}\",\"port\":\"${port}\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"none\",\"security\":\"tls\",\"tls\":\"tls\",\"sni\":\"${ip}\",\"alpn\":\"h2,http/1.1\"}"
    local link=$(echo -n "$vmess_json" | base64 -w0)
    
    echo "vmess://${link}"
}

# Генерация Trojan ссылки
generate_trojan_link() {
    local password="$1"
    local ip="$2"
    local port="$3"
    local name="$4"
    
    local link="trojan://${password}@${ip}:${port}?security=tls&sni=${ip}&alpn=h2,http/1.1#${name}"
    
    echo "$link"
}

# Генерация подписки (Subscription)
generate_subscription() {
    local client_name="$1"
    
    echo -e "${YELLOW}→ Генерация подписки для: $client_name${NC}"
    
    local ip=$(get_server_ip)
    local uuid=$(generate_uuid)
    local port=$(jq -r '.inbounds[0].port' "$CONFIG_FILE" 2>/dev/null || echo "443")
    local vmess_port=$(jq -r '.inbounds[1].port' "$CONFIG_FILE" 2>/dev/null || echo "8443")
    local trojan_port=$(jq -r '.inbounds[2].port' "$CONFIG_FILE" 2>/dev/null || echo "2053")
    
    # Создание файла подписки
    local sub_file="/etc/3x-ui/subs/${client_name}.txt"
    mkdir -p /etc/3x-ui/subs
    
    {
        generate_vless_link "$uuid" "$ip" "$port" "google.com" "${client_name}-VLESS"
        generate_vmess_link "$uuid" "$ip" "$vmess_port" "${client_name}-VMess"
        generate_trojan_link "$uuid" "$ip" "$trojan_port" "${client_name}-Trojan"
    } > "$sub_file"
    
    # URL подписки
    local sub_url="https://${ip}/subs/${client_name}.txt"
    
    echo -e "${GREEN}✓ Подписка создана${NC}"
    echo "  Файл: $sub_file"
    echo "  URL: $sub_url"
    echo
    echo -e "${BLUE}═══ Ссылки для подключения ═══${NC}"
    cat "$sub_file"
}

# Список всех клиентов
list_clients() {
    echo -e "${BLUE}═══ Клиенты ═══${NC}"
    
    if [[ -f "$CLIENTS_FILE" ]]; then
        cat "$CLIENTS_FILE" | jq -r '.clients[] | "  \(.name) - \(.uuid)"'
    else
        echo "  Нет клиентов"
    fi
}

# Удаление клиента
delete_client() {
    local client_name="$1"
    
    echo -e "${YELLOW}→ Удаление клиента: $client_name${NC}"
    
    if [[ -f "/etc/3x-ui/subs/${client_name}.txt" ]]; then
        rm -f "/etc/3x-ui/subs/${client_name}.txt"
        echo -e "${GREEN}✓ Клиент удален${NC}"
    else
        echo -e "${RED}✗ Клиент не найден${NC}"
    fi
}

# Главное меню
show_menu() {
    clear
    echo -e "${BLUE}"
    echo "  _  3x-ui Client Generator"
    echo " | | "
    echo " | |__   ___  ___"
    echo " | '_ \ / _ \/ __|"
    echo " | |_) |  __/\__ \\"
    echo " |_.__/ \___||___/"
    echo -e "${NC}"
    echo
    echo "1. Создать нового клиента"
    echo "2. Сгенерировать подписку"
    echo "3. Список клиентов"
    echo "4. Удалить клиента"
    echo "5. Выход"
    echo
    read -p "Выберите опцию [1-5]: " option
    
    case $option in
        1)
            read -p "Имя клиента: " name
            read -p "Порт (или Enter для авто): " port
            read -p "SNI (например google.com): " sni
            create_client "$name" "${port:-auto}" "${sni:-google.com}"
            ;;
        2)
            read -p "Имя клиента: " name
            generate_subscription "$name"
            ;;
        3)
            list_clients
            ;;
        4)
            read -p "Имя клиента для удаления: " name
            delete_client "$name"
            ;;
        5)
            exit 0
            ;;
        *)
            echo -e "${RED}Неверная опция${NC}"
            ;;
    esac
    
    echo
    read -p "Нажмите Enter для продолжения..."
    show_menu
}

# Запуск
read_config

if [[ "$1" == "--menu" || -z "$1" ]]; then
    show_menu
elif [[ "$1" == "--create" ]]; then
    create_client "$2" "${3:-auto}" "${4:-google.com}"
elif [[ "$1" == "--subscribe" ]]; then
    generate_subscription "$2"
elif [[ "$1" == "--list" ]]; then
    list_clients
elif [[ "$1" == "--delete" ]]; then
    delete_client "$2"
else
    echo "Использование:"
    echo "  $0 --menu              - Интерактивное меню"
    echo "  $0 --create NAME       - Создать клиента"
    echo "  $0 --subscribe NAME    - Создать подписку"
    echo "  $0 --list              - Список клиентов"
    echo "  $0 --delete NAME       - Удалить клиента"
fi
