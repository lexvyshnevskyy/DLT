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

Перевірте `/etc/default/delatometry`: шлях workspace, venv, пароль БД, `ROS_DOMAIN_ID`.
