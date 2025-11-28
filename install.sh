#!/bin/bash

# Завершаем выполнением скрипта при любой ошибке
set -e

# Переменные для красивого вывода (3 цвета и 1 для сброса)
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
GREEN='\033[0;32m'

# Переменная с указанием нашего файла со скриптом
# В теории можно было ограничиться одним файлом install.sh, если сделать загрузку обнов с того же гитхаба, но пусть будет так для простоты
MONITOR_SCRIPT="monitor.sh"

# Переменные, задаваемые при запуске через аргументы
ENV_FILE=""
APP_URL=""
APP_SERVICE=""

CHECK_INTERVAL=30

# Флаги для обновления или удаления мониторинга
UPDATE=0
DELETE=0

# Инициализируем функция для help-команд
print_help() {
    cat <<EOF
Использование: $0 install [OPTIONS]

Опции:
  --url URL          URL приложения
  --service NAME     systemd-сервис для перезапуска
  --update           Обновить текущий скрипт (опционально)
  --delete           Удалить мониторинг для данного сервиса (опционально)
  --interval N       Интервал проверки в секундах (опционально, по умолчанию $CHECK_INTERVAL)
Пример:
  # Использование скрипта мониторинга
  $0 --url http://localhost:8080 --service myapp --interval 30

  # Обновление скрипта мониторинга
  $0 --url http://localhost:8080 --service myapp --interval 30 --update

  # Удаление
  ./install.sh --url localhost:8080 --service myapp --delete
EOF
    exit 0
}

# Инициализируем нашу функцию для логирования с INFO и DEBUG уровнями
log() {
    local level="$1"
    local msg="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    case "$level" in
        INFO)
            echo -e "${GREEN}[$timestamp] ${BLUE}[INFO]${NC} $msg"
            ;;
        ERROR)
            echo -e "${GREEN}[$timestamp] ${RED}[ERROR]${NC} $msg"
            ;;
        *)
            echo -e "${GREEN}[$timestamp]${NC} $msg"
            ;;
    esac
}

# Парсинг аргументов
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --url)
                APP_URL="$2"
                shift 2
                ;;
            --service)
                APP_SERVICE="$2"
                shift 2
                ;;
            --interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            --update)
                UPDATE=1
                shift
                ;;
            --delete)
                DELETE=1
                shift
                ;;
            -h|--help)
                print_help
                ;;
            *)
                log ERROR "Неизвестный аргумент: $1"
                print_help
                ;;
        esac
    done
}

# Валидируем наши аргументы и проверяем наличие нашего сервиса в systemd-units
validate_vars() {
    if [[ -z "$APP_URL" ]]; then
        log ERROR "Не указан URL сервиса (--url)"
        exit 1
    fi

    if [[ -z "$APP_SERVICE" ]]; then
        log ERROR "Не указан systemd-сервис (--service)"
        exit 1
    fi

    if ! systemctl list-unit-files | grep -q "^${APP_SERVICE}.service"; then
        log ERROR "Сервис $APP_SERVICE не найден"
        exit 1
    else
        log INFO "Сервис $APP_SERVICE найден"
    fi

    # Делаем динамические имена сервисов/таймеров под каждый сервис
    SERVICE_PREFIX="monitor_${APP_SERVICE}"
    SERVICE_NAME="${SERVICE_PREFIX}.service"
    TIMER_NAME="${SERVICE_PREFIX}.timer"
    INSTALL_PATH="/usr/local/bin/${SERVICE_PREFIX}.sh"
}

# Функция для установки нашего основного скрипта мониторинга и его обновления
install_monitor() {
    if [[ -f "$INSTALL_PATH" && $UPDATE -eq 0 ]]; then
        log INFO "Скрипт уже установлен. Используйте --update для перезаписи"
    else
        log INFO "Устанавливаем скрипт мониторинга в $INSTALL_PATH..."
        sudo cp "$MONITOR_SCRIPT" "$INSTALL_PATH"
        sudo chmod +x "$INSTALL_PATH"
    fi
}

# Функция для создания systemd сервиса | запускаем наш основной скрипт с параметрами, которые были переданы во время запуска ./install
create_service() {
    log INFO "Создаем systemd сервис $SERVICE_NAME..."
    sudo tee /etc/systemd/system/$SERVICE_NAME > /dev/null <<EOF
[Unit]
Description=Monitoring for ${APP_SERVICE}

[Service]
Type=oneshot
ExecStart=$INSTALL_PATH --url ${APP_URL} --service ${APP_SERVICE}
EOF
}

# Функция для создания systemd таймера | будем с помощью него запускать systemd-сервис с нашим основным скриптом
create_timer() {
    log INFO "Создаем systemd таймер $TIMER_NAME..."
    sudo tee /etc/systemd/system/$TIMER_NAME > /dev/null <<EOF
[Unit]
Description=Timer for monitoring ${APP_SERVICE}

[Timer]
OnBootSec=1sec
AccuracySec=1s
OnUnitActiveSec=${CHECK_INTERVAL}sec
Unit=${SERVICE_NAME}

[Install]
WantedBy=timers.target
EOF
}

# Перечитываем systemd файлы и запускаем наш таймер
enable_timer() {
    log INFO "Перезагружаем systemd и активируем таймер..."
    sudo systemctl daemon-reload
    sudo systemctl enable --now $TIMER_NAME
    log INFO "Установлена проверка каждые $CHECK_INTERVAL секунд"
}

# Функция для удаления нашего "монитора" для конкретного сервиса
delete_monitor() {
    log INFO "Удаляем мониторинг для $APP_SERVICE..."

    sudo systemctl disable --now "$TIMER_NAME" 2>/dev/null || true

    sudo systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true

    sudo rm -f "/etc/systemd/system/$TIMER_NAME"
    sudo rm -f "/etc/systemd/system/$SERVICE_NAME"

    sudo rm -f "$INSTALL_PATH"

    sudo systemctl daemon-reload

    log INFO "Удаление завершено."
    exit 0
}

# Просто по привычки основная функция для входа
main() {
    parse_args "$@"
    validate_vars
    if [[ $DELETE -eq 1 ]]; then
        delete_monitor
    fi
    install_monitor
    create_service
    create_timer
    enable_timer
}

main "$@"