# systemd-app-monitor

---

Проект состоит из двух скриптов:

- **monitor.sh** — выполняет проверку доступности и перезапуск сервиса (основной скрипт)
- **install.sh** — устанавливает monitor.sh для сервиса, создаёт systemd service + timer
---

## Установка
```bash
git clone https://github.com/<username>/systemd-app-monitor.git
cd systemd-app-monitor
chmod +x install.sh
```

## Использование `install.sh`
> ⚠️ Для установки требуется root-доступ, так как скрипт создаёт systemd-unit файлы.


Установка мониторинга для сервиса (по умолчанию проверка каждые 30 секунд)
```bash
sudo ./install.sh --url http://localhost:8080 --service myapp
```

Установка с кастомным интервалом (например, каждые 15 секунд)
```bash
sudo ./install.sh --url http://localhost:8080 --service myapp --interval 15
```

Обновление скрипта мониторинга (при правках в сам monitor.sh)
```bash
sudo ./install.sh --url http://localhost:8080 --service myapp --update
```

Удаление мониторинга конкретного сервиса
```bash
sudo ./install.sh --url http://localhost:8080 --service myapp --delete
```

## Аргументы `install.sh`

| Флаг             | Описание                                            | Обязательно | Пример                                |
|------------------|-----------------------------------------------------|-------------|---------------------------------------|
| `--url URL`      | URL, который будет проверяться через `curl`         | ✅          | `--url http://localhost:8080/healthz` |
| `--service NAME` | systemd-сервис, который нужно перезапускать         | ✅          | `--service myapp`                     |
| `--interval N`   | Интервал проверки в секундах                        | ❌ (30 по умолчанию) | `--interval 15`                       |
| `--update`       | Обновляет установленный монитор (перезапись скрипта) | ❌ | `--update`                            |
| `--delete`       | Удаляет мониторинг и связанные systemd units        | ❌          | `--delete`                            |
| `--help`         | Просмотр доп.информации по запуску скрипта          | ❌          | `--help`                              |