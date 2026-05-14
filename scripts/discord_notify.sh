#!/bin/bash
#============================================================================
# 3x-ui - Discord уведомления
#============================================================================

DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
CONFIG_FILE="/etc/3x-ui/discord_config.conf"

# Чтение конфигурации
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Функция отправки сообщения
send_message() {
    local message="$1"
    local webhook="${2:-$DISCORD_WEBHOOK}"
    
    if [[ -z "$webhook" ]]; then
        echo "Ошибка: Webhook не настроен"
        return 1
    fi
    
    curl -s -X POST "$webhook" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"$message\"}"
}

# Функция отправки embed
send_embed() {
    local title="$1"
    local description="$2"
    local color="${3:-3447003}"
    local webhook="${4:-$DISCORD_WEBHOOK}"
    
    local json=$(cat <<EOF
{
    "embeds": [
        {
            "title": "$title",
            "description": "$description",
            "color": $color,
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
            "footer": {
                "text": "3x-ui Notification System"
            }
        }
    ]
}
EOF
)
    
    curl -s -X POST "$webhook" \
        -H "Content-Type: application/json" \
        -d "$json"
}

# Уведомление о новом клиенте
notify_new_client() {
    local client_name="$1"
    local uuid="$2"
    local port="$3"
    local protocol="$4"
    
    send_embed \
        "🎉 Новый клиент создан" \
        "**Имя:** $client_name\n**Протокол:** $protocol\n**UUID:** \`$uuid\`\n**Порт:** $port" \
        "3066993"
}

# Уведомление об удалении клиента
notify_delete_client() {
    local client_name="$1"
    
    send_embed \
        "🗑️ Клиент удален" \
        "**Имя:** $client_name" \
        "15158332"
}

# Уведомление о подключении
notify_connection() {
    local ip="$1"
    local protocol="$2"
    local port="$3"
    
    send_embed \
        "🔗 Новое подключение" \
        "**IP:** $ip\n**Протокол:** $protocol\n**Порт:** $port" \
        "3447003"
}

# Мониторинг системы
notify_system_status() {
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local ram=$(free -m | awk 'NR==2{printf "%.0f%%", $3*100/$2}')
    local disk=$(df -h / | awk 'NR==2{print $5}')
    local uptime=$(uptime -p)
    
    send_embed \
        "📊 Статус сервера" \
        "**CPU:** ${cpu}%\n**RAM:** ${ram}\n**Disk:** ${disk}\n**Uptime:** ${uptime}" \
        "3447003"
}

# Уведомление об ошибке
notify_error() {
    local error="$1"
    
    send_embed \
        "❌ Ошибка" \
        "\`$error\`" \
        "15158332"
}

# Настройка webhook
setup_webhook() {
    local webhook="$1"
    
    mkdir -p /etc/3x-ui
    echo "DISCORD_WEBHOOK=\"$webhook\"" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    
    echo "✓ Webhook настроен"
}

# Главная функция
main() {
    case "$1" in
        --setup)
            setup_webhook "$2"
            ;;
        --new-client)
            notify_new_client "$2" "$3" "$4" "$5"
            ;;
        --delete-client)
            notify_delete_client "$2"
            ;;
        --connection)
            notify_connection "$2" "$3" "$4"
            ;;
        --status)
            notify_system_status
            ;;
        --error)
            notify_error "$2"
            ;;
        --message)
            send_message "$2"
            ;;
        *)
            echo "Использование:"
            echo "  $0 --setup WEBHOOK_URL       - Настроить webhook"
            echo "  $0 --new-client NAME UUID PORT PROTOCOL"
            echo "  $0 --delete-client NAME"
            echo "  $0 --connection IP PROTO PORT"
            echo "  $0 --status                  - Статус сервера"
            echo "  $0 --error MESSAGE           - Ошибка"
            echo "  $0 --message TEXT            - Произвольное сообщение"
            ;;
    esac
}

main "$@"
