# Go HTTP Server

Простой HTTP-сервер на Go. Поддерживает 2 ендпоинта (`/healthz`) и (`/`).

---

## Сборка бинарника
```bash
go build -o main main.go
```

---

## Запуск
```bash
./main
#or
go run main
```
---

## Переменные окружения

| Переменная | Описание | Значение по умолчанию |
|------------|----------|----------------------|
| `HOST`     | Адрес для сервера | `localhost` |
| `PORT`     | Порт сервера | `8080` |

---

## Простой systemd-unit для сервиса
```bash
#vkapp.service
[Unit]
Description=Simple go HTTP server
After=network.target

[Service]
Type=simple
WorkingDirectory=path_to_work_directory # example /home/lutin/vk
ExecStart=path_to_execute_file # # example /home/lutin/vk/main
Restart=on-failure

[Install]
WantedBy=multi-user.target
```