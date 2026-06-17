# Служби systemd

Встановлення: `scripts/systemd/install_services.sh` (викликається з `scripts/install.sh`).

## Основні юніти

| Юніт | Роль |
|------|------|
| `delatometry-database.service` | Вузол запитів до MariaDB |
| `delatometry-ltm2985.service` | Драйвер LTM2985 |
| `delatometry-measure-device.service` | Імпедансметр E7-20 |
| `delatometry-im3536.service` | LCR-метр Hioki IM3536 |
| `delatometry-ads1256.service` | Опційний АЦП |
| `delatometry-core.service` | Експеримент + PI + журнал |
| `delatometry-hmi.service` | Nextion по RS-232 |
| `delatometry-webui.service` | FastAPI, порт 80 |
| `delatometry-vpn.service` | VPN при старті (за `/etc/delatometry/vpn.json`) |

## Середовище

`/etc/default/delatometry` підхоплює `scripts/systemd/run_node.sh`.

| Змінна | Призначення |
|--------|-------------|
| `DELATOMETRY_WORKSPACE`, `DELATOMETRY_VENV` | Workspace і venv |
| `ROS_DOMAIN_ID` | Домен ROS 2 |
| `DELATOMETRY_MEASURE_SOURCE` | `e720` / `im3536` |
| `DELATOMETRY_RPI_MODEL` | `rpi4` / `rpi5` |
| `DELATOMETRY_PWM_BACKEND` | `pigpio` / `lgpio` |
| `DELATOMETRY_HMI_PORT` | UART для Nextion |
| `DELATOMETRY_WEBUI_RUN_CHARTS_DIR` | Каталог PNG графіків запусків |
| `DELATOMETRY_DB_*` | MariaDB |

Інсталятор створює `/var/lib/delatometry/run_charts`. На Pi 5 `delatometry-ads1256` не залежить від `pigpiod`.

## Команди оператора

```bash
~/ros2_delatometry/scripts/systemd/status.sh
~/ros2_delatometry/scripts/systemd/logs.sh all
sudo systemctl restart delatometry-core
```

На сторінці **Панель** можна керувати службами, якщо налаштовано sudo (`src/webui/scripts/install_sudoers.sh`).

## Параметри core

Для повного функціоналу експериментів:

- `enable_pwm_controller:=true` — лише для режиму **`default`**
- `enable_database_client:=true`
- `enable_program_scheduler:=true` — також для `measure_only` / `measure_ltm` без PWM

Див. `src/core/config/core.params.yaml`.
