#!/bin/bash
#============================================================================
# 3x-ui - Полная установка
# Оптимизировано для 512MB RAM / 1GB Disk
#============================================================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Логотип
print_logo() {
    echo -e "${BLUE}"
    echo "  _  3x-ui Installer"
    echo " | | "
    echo " | |__   ___  ___"
    echo " | '_ \ / _ \/ __|"
    echo " | |_) |  __/\__ \\"
    echo " |_.__/ \___||___/"
    echo -e "${NC}"
}

# Проверка root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Ошибка: Запустите скрипт от root${NC}"
        exit 1
    fi
}

# Проверка ОС
check_os() {
    if [[ -f /etc/debian_version ]]; then
        OS="debian"
    elif [[ -f /etc/redhat-release ]]; then
        OS="centos"
    elif [[ -f /etc/alpine-release ]]; then
        OS="alpine"
    else
        echo -e "${RED}Ошибка: Неподдерживаемая ОС${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ ОС: $OS${NC}"
}

# Оптимизация системы для 512MB RAM
optimize_system() {
    echo -e "${YELLOW}→ Оптимизация системы...${NC}"
    
    # Отключение swap (если есть)
    if grep -q "swap" /proc/swaps; then
        swapoff -a 2>/dev/null || true
    fi
    
    # Настройка sysctl для низкой памяти
    cat > /etc/sysctl.d/99-3xui-optimize.conf << 'SYSCTL'
vm.swappiness = 1
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 32768
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
SYSCTL
    sysctl --system >/dev/null 2>&1
    
    # Очистка кэша
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    
    echo -e "${GREEN}✓ Система оптимизирована${NC}"
}

# Установка зависимостей
install_dependencies() {
    echo -e "${YELLOW}→ Установка зависимостей...${NC}"
    
    if [[ "$OS" == "debian" ]]; then
        apt-get update -qq
        apt-get install -y -qq curl wget socat cron netfilter-persistent iptables
    elif [[ "$OS" == "centos" ]]; then
        yum install -y -q curl wget socat cronie iptables-services
        systemctl enable iptables
    elif [[ "$OS" == "alpine" ]]; then
        apk add --quiet curl wget socat iptables cronie
    fi
    
    echo -e "${GREEN}✓ Зависимости установлены${NC}"
}

# Установка Xray-core
install_xray() {
    echo -e "${YELLOW}→ Установка Xray-core...${NC}"
    
    # Скачиваем последнюю версию
    XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    XRAY_VERSION=${XRAY_VERSION#v}
    
    curl -L -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip"
    unzip -o /tmp/xray.zip -d /usr/local/xray/
    chmod +x /usr/local/xray/xray
    
    rm -f /tmp/xray.zip
    
    echo -e "${GREEN}✓ Xray-core v${XRAY_VERSION} установлен${NC}"
}

# Создание конфигурации
create_config() {
    echo -e "${YELLOW}→ Создание конфигурации...${NC}"
    
    mkdir -p /etc/3x-ui
    
    # Генерация UUID
    UUID=$(cat /proc/sys/kernel/random/uuid)
    PORT=$((RANDOM % 64000 + 1024))
    
    # Основной конфиг
    cat > /etc/3x-ui/config.json << CONF
{
  "log": {
    "level": "warning",
    "access": "/var/log/3x-ui/access.log",
    "error": "/var/log/3x-ui/error.log"
  },
  "inbounds": [
    {
      "tag": "VLESS-TCP-Reality",
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "google.com:443",
          "xver": 0,
          "serverNames": ["google.com", "www.google.com"],
          "privateKey": "$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)",
          "minClientVer": "",
          "maxClientVer": "",
          "maxTimeDiff": 0,
          "proxyProtocolVer": 0
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "metadataOnly": false
      }
    },
    {
      "tag": "VMLESS-TCP",
      "port": $((PORT + 1)),
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["h2", "http/1.1"]
        }
      }
    },
    {
      "tag": "TROJAN-TCP",
      "port": $((PORT + 2)),
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "${UUID}"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "domain": ["geosite:category-ads-all"],
        "outboundTag": "blocked"
      }
    ]
  },
  "dns": {
    "servers": [
      "1.1.1.1",
      "8.8.8.8",
      "localhost"
    ],
    "queryStrategy": "UseIP"
  }
}
CONF
    
    # Сохранение данных для клиента
    cat > /etc/3x-ui/client_info.txt << INFO
UUID: ${UUID}
PORT: ${PORT}
VMess_PORT: $((PORT + 1))
Trojan_PORT: $((PORT + 2))
INFO
    
    # Лог директория
    mkdir -p /var/log/3x-ui
    
    echo -e "${GREEN}✓ Конфигурация создана${NC}"
    echo -e "${YELLOW}  Порт VLESS: ${PORT}${NC}"
    echo -e "${YELLOW}  Порт VMess: $((PORT + 1))${NC}"
    echo -e "${YELLOW}  Порт Trojan: $((PORT + 2))${NC}"
}

# Настройка DNS
setup_dns() {
    echo -e "${YELLOW}→ Настройка DNS...${NC}"
    
    # Резервная копия
    cp /etc/resolv.conf /etc/resolv.conf.bak
    
    # Оптимизированный DNS
    cat > /etc/resolv.conf << 'DNS'
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 9.9.9.9
options ndots:5
options timeout:2
DNS
    
    # Защита DNS
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    echo -e "${GREEN}✓ DNS настроен${NC}"
}

# Настройка firewall
setup_firewall() {
    echo -e "${YELLOW}→ Настройка firewall...${NC}"
    
    # Открытие портов
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    
    # Сохранение правил
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    elif command -v iptables-save &> /dev/null; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4
    fi
    
    echo -e "${GREEN}✓ Firewall настроен${NC}"
}

# Создание systemd сервиса
create_service() {
    echo -e "${YELLOW}→ Создание systemd сервиса...${NC}"
    
    cat > /etc/systemd/system/3x-ui.service << 'SERVICE'
[Unit]
Description=3x-ui Service
Documentation=https://github.com/kayucm21/3x-ui2011
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/xray
ExecStart=/usr/local/xray/xray run -config /etc/3x-ui/config.json
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SERVICE
    
    systemctl daemon-reload
    systemctl enable 3x-ui
    systemctl start 3x-ui
    
    echo -e "${GREEN}✓ Сервис создан и запущен${NC}"
}

# Discord уведомления
setup_discord() {
    echo -e "${YELLOW}→ Настройка Discord уведомлений...${NC}"
    
    # Скрипт уведомления
    cat > /etc/3x-ui/discord_notify.sh << 'DISCORD'
#!/bin/bash
DISCORD_WEBHOOK="${1:-}"
MESSAGE="${2:-}"

if [[ -z "$DISCORD_WEBHOOK" ]]; then
    exit 0
fi

curl -s -X POST "$DISCORD_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"🔔 3x-ui Alert: $MESSAGE\"}"
DISCORD
    
    chmod +x /etc/3x-ui/discord_notify.sh
    
    # Добавление в cron для мониторинга
    (crontab -l 2>/dev/null; echo "*/5 * * * * /etc/3x-ui/discord_notify.sh \"YOUR_WEBHOOK\" \"Server status: OK\"") | crontab -
    
    echo -e "${GREEN}✓ Discord уведомления настроены${NC}"
}

# Вывод информации
print_info() {
    clear
    print_logo
    
    echo -e "${GREEN}╔════════════════════════════════════════╗"
    echo -e "║   3x-ui успешно установлен!          ║"
    echo -e "╚════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}📊 Информация о сервере:${NC}"
    echo "  IP: $(curl -s ifconfig.me)"
    echo "  RAM: $(free -m | awk 'NR==2{printf "%.0fMB", $2}')"
    echo "  Disk: $(df -h / | awk 'NR==2{print $3 "/" $2}')"
    echo
    echo -e "${YELLOW}🔑 Данные клиента:${NC}"
    cat /etc/3x-ui/client_info.txt | sed 's/^/  /'
    echo
    echo -e "${YELLOW}📋 Команды управления:${NC}"
    echo "  systemctl start 3x-ui    - Запуск"
    echo "  systemctl stop 3x-ui     - Остановка"
    echo "  systemctl restart 3x-ui  - Перезапуск"
    echo "  systemctl status 3x-ui   - Статус"
    echo
    echo -e "${GREEN}✓ Установка завершена!${NC}"
}

# Основной процесс
main() {
    print_logo
    echo -e "${YELLOW}Начало установки...${NC}"
    echo
    
    check_root
    check_os
    optimize_system
    install_dependencies
    install_xray
    create_config
    setup_dns
    setup_firewall
    create_service
    setup_discord
    print_info
}

main "$@"
