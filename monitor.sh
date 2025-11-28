#!/bin/bash

# Завершаем выполнением скрипта при любой ошибке
set -e

# Переменные для красивого вывода (3 цвета и 1 для сброса)
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
GREEN='\033[0;32m'

# Наши переменные (задаём через аргументы)
APP_URL=""
APP_SERVICE=""

# Инициализируем функция для help-команд
print_help() {
    cat <<EOF
Использование: $0 [OPTIONS]

Опции:
  --env PATH         Путь к файлу .env (если указан - переменные берутся оттуда) (опционально)
  --url URL          URL, по которому проверяется приложение
  --service NAME     Название systemd-сервиса, который нужно перезапустить

Примеры:
  # Базовый синтаксис для мониторинга сервиса
  $0 --url http://localhost:8080 --service myapp
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
            -h|--help)
                print_help
                ;;
            *)
                log ERROR "Неизвестная аргумент: $1"
                print_help
                ;;
        esac
    done
}

# Валидируем наши аргументы и проверяем наличие нашего сервиса в systemd-units
validate_vars() {
    if [[ -z "$APP_URL" ]]; then
         log ERROR "Не указан URL сервиса(--url)"
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
}

# Проверяем наш сервис на живность
check_app() {
    if ! output=$(curl -sS --fail "$APP_URL" -o /dev/null 2>&1); then
        log ERROR "Сервис недоступен"
        log ERROR "Ошибка: $output"
        log ERROR "Перезапуск сервиса $APP_SERVICE..."
        systemctl restart "$APP_SERVICE"
    else
        log INFO "Сервис $APP_SERVICE доступен"
    fi
}

# Просто по привычки основная функция для входа
main() {
    parse_args "$@"
    validate_vars
    check_app
}

main "$@"