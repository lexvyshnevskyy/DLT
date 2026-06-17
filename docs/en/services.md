# Systemd services

Services are installed by `scripts/systemd/install_services.sh` (called from `scripts/install.sh`). Units live under `scripts/systemd/` and are customized for `DELATOMETRY_WORKSPACE` and the Python venv.

## Main units

| Unit | Package / role |
|------|----------------|
| `delatometry-database.service` | MariaDB query node |
| `delatometry-ltm2985.service` | LTM2985 UART driver |
| `delatometry-measure-device.service` | E7-20 impedance meter |
| `delatometry-im3536.service` | Hioki IM3536 LCR meter |
| `delatometry-ads1256.service` | Optional ADC (may be disabled) |
| `delatometry-core.service` | Experiment + PI + logging |
| `delatometry-hmi.service` | Nextion RS-232 HMI |
| `delatometry-webui.service` | FastAPI on port 80 (default) |
| `delatometry-vpn.service` | Optional VPN on boot (`/etc/delatometry/vpn.json`) |

## Environment

`/etc/default/delatometry` is sourced by `scripts/systemd/run_node.sh`. Typical variables:

| Variable | Purpose |
|----------|---------|
| `DELATOMETRY_WORKSPACE` | Colcon workspace path |
| `DELATOMETRY_VENV` | Python venv for nodes |
| `ROS_DOMAIN_ID` | ROS 2 domain (must match all nodes) |
| `DELATOMETRY_MEASURE_SOURCE` | `e720` or `im3536` |
| `DELATOMETRY_RPI_MODEL` | `rpi4` or `rpi5` (set by installer) |
| `DELATOMETRY_PWM_BACKEND` | `pigpio` (Pi 4) or `lgpio` (Pi 5) |
| `DELATOMETRY_CORE_ENABLE_PWM_CONTROLLER` | Heater PWM in core |
| `DELATOMETRY_HMI_PORT` | Nextion UART device (e.g. `/dev/serial0`) |
| `DELATOMETRY_WEBUI_RUN_CHARTS_DIR` | Persistent PNG charts (`/var/lib/delatometry/run_charts`) |
| Database credentials | `DELATOMETRY_DB_*` |

The installer creates `/var/lib/delatometry/run_charts` owned by the service user. On Pi 5, `delatometry-ads1256` does not depend on `pigpiod`.

## Operator commands

```bash
# Status of all units
~/ros2_delatometry/scripts/systemd/status.sh

# Follow logs
~/ros2_delatometry/scripts/systemd/logs.sh all
~/ros2_delatometry/scripts/systemd/logs.sh delatometry-core

# Restart one service
sudo systemctl restart delatometry-core

# Restart stack after code deploy
sudo systemctl restart delatometry-database delatometry-ltm2985 \
  delatometry-measure-device delatometry-im3536 delatometry-core delatometry-webui
```

The **Dashboard** page in the Web UI can start/stop/restart units when passwordless sudo is configured (`src/webui/scripts/install_sudoers.sh`).

## Boot order

VPN (if enabled) may start before webui. Database and sensor nodes should be up before **core**, which expects LTM control traffic and DB connectivity. Webui can start independently; it reconnects to ROS services when available.

## Core launch parameters

Core requires (for full experiment features):

- `enable_pwm_controller:=true` — required for **`default`** experiment mode only
- `enable_database_client:=true`
- `enable_program_scheduler:=true` — also used for timed modes (`measure_only`, `measure_ltm`) without PWM

See `src/core/config/core.params.yaml` for watchdog, topic names, and PI gains.
