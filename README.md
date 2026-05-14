# 3x-ui

**Панель управления VPN на базе Xray-core**

Оптимизировано для серверов с **512MB RAM** и **1GB Disk**

## 🚀 Протоколы

- **VLESS** (Reality)
- **VMess** (TLS)
- **Trojan** (TLS)

## 📦 Установка

### Автоматическая установка

```bash
curl -o install.sh https://raw.githubusercontent.com/kayucm21/3x-ui2011/main/install/install.sh
chmod +x install.sh
./install.sh
```

### Ручная установка

```bash
# Склонировать репозиторий
git clone https://github.com/kayucm21/3x-ui2011.git
cd 3x-ui2011

# Запустить установку
sudo bash install/install.sh
```

## 🔄 Обновление

```bash
sudo bash install/update.sh
```

## 🗑️ Удаление

```bash
sudo bash install/uninstall.sh
```

## 👥 Управление клиентами

### Интерактивное меню

```bash
sudo bash scripts/generate_client.sh --menu
```

### Создать клиента

```bash
sudo bash scripts/generate_client.sh --create "client_name"
```

### Создать подписку

```bash
sudo bash scripts/generate_client.sh --subscribe "client_name"
```

### Список клиентов

```bash
sudo bash scripts/generate_client.sh --list
```

### Удалить клиента

```bash
sudo bash scripts/generate_client.sh --delete "client_name"
```

## 🔔 Discord уведомления

### Настройка

```bash
# Установить webhook
sudo bash scripts/discord_notify.sh --setup "YOUR_WEBHOOK_URL"
```

### Использование

```bash
# Отправить сообщение
sudo bash scripts/discord_notify.sh --message "Текст сообщения"

# Статус сервера
sudo bash scripts/discord_notify.sh --status

# Уведомление о новом клиенте
sudo bash scripts/discord_notify.sh --new-client "name" "uuid" "port" "protocol"
```

## ⚡ Оптимизация

### Полная оптимизация

```bash
sudo bash scripts/optimize.sh --all
```

### Отдельные оптимизации

```bash
sudo bash scripts/optimize.sh --memory    # Память
sudo bash scripts/optimize.sh --disk      # Диск
sudo bash scripts/optimize.sh --network   # Сеть
sudo bash scripts/optimize.sh --cleanup   # Очистка
sudo bash scripts/optimize.sh --stats     # Статистика
```

## 📋 Команды управления

```bash
# Старт
sudo systemctl start 3x-ui

# Стоп
sudo systemctl stop 3x-ui

# Перезапуск
sudo systemctl restart 3x-ui

# Статус
sudo systemctl status 3x-ui

# Логи
sudo journalctl -u 3x-ui -f
```

## 📁 Структура файлов

```
3x-ui/
├── install/
│   ├── install.sh      # Скрипт установки
│   ├── update.sh       # Скрипт обновления
│   └── uninstall.sh    # Скрипт удаления
├── scripts/
│   ├── generate_client.sh  # Генерация клиентов
│   ├── discord_notify.sh   # Discord уведомления
│   └── optimize.sh         # Оптимизация системы
├── config/
│   └── config.json     # Конфигурация Xray
└── web/
    └── ...             # Веб-интерфейс
```

## 🔧 Конфигурация

Основной конфиг: `/etc/3x-ui/config.json`

Логи:
- Access: `/var/log/3x-ui/access.log`
- Error: `/var/log/3x-ui/error.log`

## 🌐 DNS настройки

Конфигурация DNS в `/etc/resolv.conf`:

```
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 9.9.9.9
```

## 🔒 Безопасность

- Firewall настроен автоматически
- UUID генерируется для каждого клиента
- Reality протокол для VLESS
- TLS для VMess и Trojan

## 📊 Системные требования

- **RAM:** 512MB (минимум)
- **Disk:** 1GB (минимум)
- **OS:** Debian 10+, Ubuntu 18+, CentOS 7+
- **CPU:** 1 ядро (минимум)

## 📞 Поддержка

- GitHub Issues: https://github.com/kayucm21/3x-ui2011/issues
- Discord: [ссылка]

## 📄 Лицензия

MIT License

---

**© 2024 3x-ui** | [kayucm21/3x-ui2011](https://github.com/kayucm21/3x-ui2011)
