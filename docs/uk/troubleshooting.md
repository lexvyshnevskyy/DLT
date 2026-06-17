# Усунення несправностей

## Веб-UI «підключається» або порожній експеримент

1. `systemctl status delatometry-core`
2. `ros2 topic echo /core/experiment/status --once`
3. `sudo systemctl restart delatometry-webui`

## Старт програми зависає

- Чиста перезбірка **core** на Pi (застарілий код з `future.result(timeout=)` у callback давав deadlock).
- Увімкнені scheduler, PWM, клієнт БД.
- Watchdog LTM — канал керування має оновлюватися.

## У БД Running, а core простоює

- Перезапуск core; перевірка `program_runs` у MariaDB.

## Немає вимірювань

- Активна `delatometry-database.service`
- Логи: `scripts/systemd/logs.sh delatometry-core`

## HMI не збігається з реальністю

- Орієнтир — `/core/experiment/status`; перезапуск `delatometry-hmi`.

## Документація 404

```bash
colcon build --packages-select webui
pip install markdown>=3.5
```

## Логи

```bash
~/ros2_delatometry/scripts/systemd/status.sh
journalctl -u delatometry-webui -f
```

Перевірте `/etc/default/delatometry`: workspace, venv, пароль БД, `ROS_DOMAIN_ID`, модель Pi, PWM, порт HMI, каталог графіків.

## PWM / нагрівач не працює

| Симптом | Pi 4 | Pi 5 |
|---------|------|------|
| pigpiod у панелі | `sudo systemctl enable --now pigpiod` | **Не використовуйте pigpiod** |
| PWM увімкнено, немає виходу | Configuration → Core → PWM, перезапуск core | `python3-lgpio`, `dtoverlay=pwm`, reboot |
| `backend=lgpio` у логах | — | Норма для Pi 5 |

Переінсталяція моделі: `RPI_MODEL=rpi5 INSTALL_MODE=rebuild bash scripts/install.sh`

## pigpiod на Pi 5

Очікувана помилка. На Pi 5 використовуйте **lgpio**:

```bash
sudo systemctl disable --now pigpiod
sudo apt install python3-lgpio
sudo systemctl restart delatometry-core
```

## Немає графіків після перезавантаження

Графіки в **`/var/lib/delatometry/run_charts`**. Відкрийте запуск у веб-UI або натисніть **Створити графіки** — дані беруться з БД.

## HMI без даних по UART

```bash
grep HMI_PORT /etc/default/delatometry
sudo reboot
journalctl -u delatometry-hmi -n 30
```
