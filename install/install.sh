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
CYAN='\033[0;36m'
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
        apt-get install -y -qq curl wget socat cron netfilter-persistent iptables unzip openssl jq python3
    elif [[ "$OS" == "centos" ]]; then
        yum install -y -q curl wget socat cronie iptables-services unzip openssl jq python3
        systemctl enable iptables
    elif [[ "$OS" == "alpine" ]]; then
        apk add --quiet curl wget socat iptables cronie unzip openssl jq python3
    fi
    
    echo -e "${GREEN}✓ Зависимости установлены${NC}"
}

# Установка Xray-core
install_xray() {
    echo -e "${YELLOW}→ Установка Xray-core...${NC}"
    
    # Скачиваем последнюю версию
    XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    XRAY_VERSION=${XRAY_VERSION#v}
    
    mkdir -p /usr/local/xray
    curl -L -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip"
    
    if ! command -v unzip &> /dev/null; then
        echo -e "${RED}Ошибка: unzip не найден. Установка прервана.${NC}"
        exit 1
    fi
    
    unzip -o /tmp/xray.zip -d /usr/local/xray/
    chmod +x /usr/local/xray/xray
    
    rm -f /tmp/xray.zip
    
    echo -e "${GREEN}✓ Xray-core v${XRAY_VERSION} установлен${NC}"
}

# Генерация Reality ключей
generate_reality_keys() {
    echo -e "${YELLOW}→ Генерация Reality ключей...${NC}"
    
    if [[ ! -f /usr/local/xray/xray ]]; then
        echo -e "${RED}Ошибка: Xray не установлен${NC}"
        exit 1
    fi
    
    local keys=$(/usr/local/xray/xray x25519 2>/dev/null)
    REALITY_PRIVATE=$(echo "$keys" | grep "Private" | awk '{print $3}')
    REALITY_PUBLIC=$(echo "$keys" | grep "Public" | awk '{print $3}')
    REALITY_SHORTID=$(openssl rand -hex 8 2>/dev/null || cat /dev/urandom | tr -dc 'a-f0-9' | head -c 16)
    
    echo -e "${GREEN}✓ Reality ключи сгенерированы${NC}"
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
          "privateKey": "${REALITY_PRIVATE}",
          "shortIds": ["${REALITY_SHORTID}"],
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
    
        # Генерация логина/пароля для панели
    PANEL_USER="admin"
    PANEL_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16)
    PANEL_PORT=$((PORT + 10))
    
    # Сохранение данных для клиента
    cat > /etc/3x-ui/client_info.txt << INFO
UUID: ${UUID}
PORT: ${PORT}
VMess_PORT: $((PORT + 1))
Trojan_PORT: $((PORT + 2))
PANEL_USER: ${PANEL_USER}
PANEL_PASS: ${PANEL_PASS}
PANEL_PORT: ${PANEL_PORT}
REALITY_PUBLIC_KEY: ${REALITY_PUBLIC}
REALITY_SHORT_ID: ${REALITY_SHORTID}
INFO
    
    # Сохранение credentials отдельно
    cat > /etc/3x-ui/panel_credentials.txt << CRED
3x-ui Panel Credentials
Generated: $(date)

Username: ${PANEL_USER}
Password: ${PANEL_PASS}
Panel Port: ${PANEL_PORT}
Panel URL: http://$(curl -s ifconfig.me):${PANEL_PORT}

Reality Public Key: ${REALITY_PUBLIC}
Reality Short ID: ${REALITY_SHORTID}
CRED
    chmod 600 /etc/3x-ui/panel_credentials.txt
    
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

# Веб-панель
setup_web_panel() {
    echo -e "${YELLOW}→ Настройка веб-панели...${NC}"
    
    # Копирование веб-файлов
    mkdir -p /etc/3x-ui/web
    
    # Если скрипт запущен из git-репозитория, копируем web/
    if [[ -d "web" && -f "web/index.html" ]]; then
        cp web/index.html /etc/3x-ui/web/
    fi
    
    # Копирование сервера
    if [[ -f "web/server.py" ]]; then
        cp web/server.py /etc/3x-ui/web_server.py
    else
        # Создаём сервер inline если файла нет
        cat > /etc/3x-ui/web_server.py << 'PYTHON'
#!/usr/bin/env python3
import http.server, socketserver, base64, sys, os
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
AUTH_FILE = "/etc/3x-ui/panel_credentials.txt"
WEB_DIR = "/etc/3x-ui/web"

def get_credentials():
    user, passwd = "admin", "admin"
    try:
        with open(AUTH_FILE, "r") as f:
            for line in f:
                if line.startswith("Username:"): user = line.split(":", 1)[1].strip()
                elif line.startswith("Password:"): passwd = line.split(":", 1)[1].strip()
    except: pass
    return user, passwd

VALID_USER, VALID_PASS = get_credentials()
VALID_AUTH = base64.b64encode(f"{VALID_USER}:{VALID_PASS}".encode()).decode()

class AuthHandler(http.server.SimpleHTTPRequestHandler):
    def do_AUTHHEAD(self):
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="3x-ui Panel"')
        self.send_header("Content-type", "text/html")
        self.end_headers()
    def do_GET(self):
        auth_header = self.headers.get("Authorization")
        if auth_header is None or not auth_header.startswith("Basic "):
            self.do_AUTHHEAD()
            self.wfile.write(b"<html><body><h1>401 Unauthorized</h1></body></html>")
            return
        if auth_header.split(" ", 1)[1] != VALID_AUTH:
            self.do_AUTHHEAD()
            self.wfile.write(b"<html><body><h1>401 Unauthorized</h1></body></html>")
            return
        super().do_GET()
    def log_message(self, format, *args): pass

if __name__ == "__main__":
    os.chdir(WEB_DIR)
    with socketserver.TCPServer(("0.0.0.0", PORT), AuthHandler) as httpd:
        print(f"3x-ui panel on port {PORT}")
        httpd.serve_forever()
PYTHON
    fi
    
    chmod +x /etc/3x-ui/web_server.py
    
    # Создание systemd сервиса для веб-панели
    cat > /etc/systemd/system/3x-ui-web.service << EOF
[Unit]
Description=3x-ui Web Panel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /etc/3x-ui/web_server.py ${PANEL_PORT}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable 3x-ui-web
    systemctl start 3x-ui-web
    
    # Открытие порта панели в firewall
    iptables -A INPUT -p tcp --dport ${PANEL_PORT} -j ACCEPT
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    elif command -v iptables-save &> /dev/null; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4
    fi
    
    echo -e "${GREEN}✓ Веб-панель запущена на порту ${PANEL_PORT}${NC}"
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

# Установка WARP
setup_warp() {
    echo -e "${YELLOW}→ Настройка WARP Cloudflare...${NC}"
    
    # Скачивание wgcf
    curl -fsSL https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_amd64 -o /usr/local/bin/wgcf
    chmod +x /usr/local/bin/wgcf
    
    # Установка WireGuard
    if [[ "$OS" == "debian" ]]; then
        apt-get install -y -qq wireguard-tools
    elif [[ "$OS" == "centos" ]]; then
        yum install -y -q wireguard-tools
    fi
    
    # Регистрация WARP
    mkdir -p /etc/3x-ui/warp
    cd /etc/3x-ui/warp
    wgcf register --accept-tos 2>/dev/null || true
    wgcf generate 2>/dev/null || true
    
    # Сохранение данных WARP
    if [[ -f wgcf-profile.conf ]]; then
        cp wgcf-profile.conf /etc/3x-ui/warp/wgcf.conf
        WARP_ID=$(grep "Interface" wgcf-profile.conf -A5 | grep "PrivateKey" | cut -d= -f2 | tr -d ' ')
        echo "WARP_PRIVATE_KEY: ${WARP_ID}" >> /etc/3x-ui/panel_credentials.txt
        echo -e "${GREEN}✓ WARP настроен${NC}"
    else
        echo -e "${YELLOW}⚠ WARP не настроен (опционально)${NC}"
    fi
}

# Вывод информации
print_info() {
    clear
    print_logo
    
    local SERVER_IP=$(curl -s ifconfig.me)
    
    echo -e "${GREEN}╔════════════════════════════════════════╗"
    echo -e "║   3x-ui успешно установлен!          ║"
    echo -e "╚════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🌐 ПАНЕЛЬ УПРАВЛЕНИЯ${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}URL:${NC}     http://${SERVER_IP}:${PANEL_PORT}"
    echo -e "  ${GREEN}Логин:${NC}   ${PANEL_USER}"
    echo -e "  ${GREEN}Пароль:${NC}  ${PANEL_PASS}"
    echo
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔌 ПРОТОКОЛЫ / ПОРТЫ${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}VLESS:${NC}   ${SERVER_IP}:${PORT}"
    echo -e "  ${GREEN}VMess:${NC}   ${SERVER_IP}:$((PORT + 1))"
    echo -e "  ${GREEN}Trojan:${NC}  ${SERVER_IP}:$((PORT + 2))"
    echo
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔗 ССЫЛКИ ДЛЯ ПОДКЛЮЧЕНИЯ${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}Reality Public Key:${NC} ${REALITY_PUBLIC}"
    echo -e "  ${GREEN}Reality Short ID:${NC}   ${REALITY_SHORTID}"
    echo
    echo -e "  ${GREEN}VLESS:${NC}"
    echo -e "    vless://${UUID}@${SERVER_IP}:${PORT}?encryption=none&security=reality&sni=google.com&fp=chrome&pbk=${REALITY_PUBLIC}&sid=${REALITY_SHORTID}&type=tcp&flow=xtls-rprx-vision#3x-ui-VLESS"
    echo
    echo -e "  ${GREEN}VMess:${NC}"
    local vmess_json="{\"v\":\"2\",\"ps\":\"3x-ui-VMess\",\"add\":\"${SERVER_IP}\",\"port\":\"$((PORT + 1))\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"none\",\"security\":\"tls\"}"
    echo -e "    vmess://$(echo -n "$vmess_json" | base64 -w0)"
    echo
    echo -e "  ${GREEN}Trojan:${NC}"
    echo -e "    trojan://${UUID}@${SERVER_IP}:$((PORT + 2))?security=tls&sni=${SERVER_IP}#3x-ui-Trojan"
    echo
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🛡️  WARP CLOUDFLARE${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    if [[ -f /etc/3x-ui/warp/wgcf-profile.conf ]]; then
        echo -e "  ${GREEN}Статус:${NC}  Установлен (реальный IP скрыт)"
        echo -e "  ${GREEN}Запуск:${NC}  bash /etc/3x-ui/scripts/warp.sh --start"
    else
        echo -e "  ${YELLOW}Статус:${NC}  Не установлен"
        echo -e "  ${YELLOW}Установка:${NC}  bash /etc/3x-ui/scripts/warp.sh --install"
    fi
    echo
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📊 СИСТЕМА${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo "  IP: ${SERVER_IP}"
    echo "  RAM: $(free -m | awk 'NR==2{printf "%.0fMB", $2}')"
    echo "  Disk: $(df -h / | awk 'NR==2{print $3 "/" $2}')"
    echo
    echo -e "${YELLOW}📋 Команды управления:${NC}"
    echo "  systemctl start 3x-ui      - Запуск"
    echo "  systemctl stop 3x-ui       - Остановка"
    echo "  systemctl restart 3x-ui    - Перезапуск"
    echo "  systemctl status 3x-ui     - Статус"
    echo "  bash /etc/3x-ui/scripts/change_password.sh  - Сменить пароль"
    echo "  bash /etc/3x-ui/scripts/show_data.sh        - Показать данные"
    echo
    echo -e "${GREEN}✓ Установка завершена!${NC}"
    echo
    echo -e "${RED}⚠ ВАЖНО: Сохраните эти данные! Они больше не будут показаны.${NC}"
}
    
# Копирование скриптов в систему
copy_scripts() {
    echo -e "${YELLOW}→ Копирование скриптов...${NC}"
    
    mkdir -p /etc/3x-ui/scripts
    
    # Создание скрипта показа данных
    cat > /etc/3x-ui/scripts/show_data.sh << 'SHOWDATA'
#!/bin/bash
# Показать все данные 3x-ui

echo "═════════════════════════════════════════"
echo "         3x-ui - Данные сервера"
echo "═════════════════════════════════════════"

if [[ -f /etc/3x-ui/panel_credentials.txt ]]; then
    cat /etc/3x-ui/panel_credentials.txt
else
    echo "Данные не найдены"
fi

echo
echo "═════════════════════════════════════════"
echo "         Подключения"
echo "═════════════════════════════════════════"

if [[ -f /etc/3x-ui/client_info.txt ]]; then
    cat /etc/3x-ui/client_info.txt
fi

echo
echo "═════════════════════════════════════════"
echo "         Ссылки"
echo "═════════════════════════════════════════"

SERVER_IP=$(curl -s ifconfig.me)
UUID=$(grep "UUID:" /etc/3x-ui/client_info.txt | cut -d: -f2 | tr -d ' ')
PORT=$(grep "PORT:" /etc/3x-ui/client_info.txt | cut -d: -f2 | tr -d ' ')
PBK=$(grep "REALITY_PUBLIC_KEY:" /etc/3x-ui/client_info.txt | cut -d: -f2 | tr -d ' ')
SID=$(grep "REALITY_SHORT_ID:" /etc/3x-ui/client_info.txt | cut -d: -f2 | tr -d ' ')

if [[ -n "$UUID" && -n "$PORT" ]]; then
    echo "VLESS:"
    echo "  vless://${UUID}@${SERVER_IP}:${PORT}?encryption=none&security=reality&sni=google.com&fp=chrome&pbk=${PBK}&sid=${SID}&type=tcp&flow=xtls-rprx-vision#3x-ui"
    echo
    echo "VMess:"
    VMess_PORT=$((PORT + 1))
    vmess_json="{\"v\":\"2\",\"ps\":\"3x-ui\",\"add\":\"${SERVER_IP}\",\"port\":\"${VMess_PORT}\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"none\",\"security\":\"tls\"}"
    echo "  vmess://$(echo -n "$vmess_json" | base64 -w0)"
    echo
    echo "Trojan:"
    Trojan_PORT=$((PORT + 2))
    echo "  trojan://${UUID}@${SERVER_IP}:${Trojan_PORT}?security=tls&sni=${SERVER_IP}#3x-ui"
fi
SHOWDATA
    chmod +x /etc/3x-ui/scripts/show_data.sh
    
    # Создание скрипта смены пароля
    cat > /etc/3x-ui/scripts/change_password.sh << 'CHANGEPASS'
#!/bin/bash
# Смена пароля панели 3x-ui

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CRED_FILE="/etc/3x-ui/panel_credentials.txt"

echo -e "${YELLOW}═══ Смена пароля панели 3x-ui ═══${NC}"
echo

read -p "Новый логин (Enter чтобы оставить admin): " NEW_USER
read -sp "Новый пароль (Enter для автогенерации): " NEW_PASS
echo

NEW_USER=${NEW_USER:-admin}

if [[ -z "$NEW_PASS" ]]; then
    NEW_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16)
    echo -e "${GREEN}Сгенерирован пароль: ${NEW_PASS}${NC}"
fi

# Обновление файла credentials
if [[ -f "$CRED_FILE" ]]; then
    sed -i "s/^Username:.*/Username: ${NEW_USER}/" "$CRED_FILE"
    sed -i "s/^Password:.*/Password: ${NEW_PASS}/" "$CRED_FILE"
    sed -i "s/^Panel URL:.*/Panel URL: http:\/\/\$(curl -s ifconfig.me):\$(grep Panel_Port $CRED_FILE | cut -d: -f2 | tr -d ' ')/" "$CRED_FILE"
fi

echo
echo -e "${GREEN}✓ Пароль изменен!${NC}"
echo "  Логин: ${NEW_USER}"
echo "  Пароль: ${NEW_PASS}"
CHANGEPASS
    chmod +x /etc/3x-ui/scripts/change_password.sh
    
    # Копирование WARP скрипта если есть
    if [[ -f scripts/warp.sh ]]; then
        cp scripts/warp.sh /etc/3x-ui/scripts/warp.sh
        chmod +x /etc/3x-ui/scripts/warp.sh
    fi
    
    echo -e "${GREEN}✓ Скрипты скопированы${NC}"
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
    generate_reality_keys
    create_config
    setup_dns
    setup_firewall
    create_service
    setup_web_panel
    setup_discord
    setup_warp
    copy_scripts
    print_info
}

main "$@"
