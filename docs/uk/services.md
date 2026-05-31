# Служби systemd

Встановлення: `scripts/systemd/install_services.sh` (викликається з `scripts/install.sh`).

## Основні юніти

| Юніт | Роль |
|------|------|
| `delatometry-database.service` | Вузол запитів до MariaDB |
| `delatometry-ltm2985.service` | Драйвер LTM2985 |
| `delatometry-measure-device.service` | Зовнішні вимірювання |
| `delatometry-ads1256.service` | Опційний АЦП |
| `delatometry-core.service` | Експеримент + PI + журнал |
| `delatometry-hmi.service` | Nextion по RS-232 |
| `delatometry-webui.service` | FastAPI, порт 80 |
| `delatometry-vpn.service` | VPN при старті (за `/etc/delatometry/vpn.json`) |

## Середовище

`/etc/default/delatometry` підхоплює `scripts/systemd/run_node.sh`: workspace, venv, `ROS_DOMAIN_ID`, БД.

## Команди оператора

```bash
~/ros2_delatometry/scripts/systemd/status.sh
~/ros2_delatometry/scripts/systemd/logs.sh all
sudo systemctl restart delatometry-core
```

На сторінці **Панель** можна керувати службами, якщо налаштовано sudo (`src/webui/scripts/install_sudoers.sh`).

## Параметри core

Для повного функціоналу експериментів:

- `enable_pwm_controller:=true`
- `enable_database_client:=true`
- `enable_program_scheduler:=true`

Див. `src/core/config/core.params.yaml`.
