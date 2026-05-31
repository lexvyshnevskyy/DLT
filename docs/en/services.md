# Systemd services

Services are installed by `scripts/systemd/install_services.sh` (called from `scripts/install.sh`). Units live under `scripts/systemd/` and are customized for `DELATOMETRY_WORKSPACE` and the Python venv.

## Main units

| Unit | Package / role |
|------|----------------|
| `delatometry-database.service` | MariaDB query node |
| `delatometry-ltm2985.service` | LTM2985 UART driver |
| `delatometry-measure-device.service` | External measurement interface |
| `delatometry-ads1256.service` | Optional ADC (may be disabled) |
| `delatometry-core.service` | Experiment + PI + logging |
| `delatometry-hmi.service` | Nextion RS-232 HMI |
| `delatometry-webui.service` | FastAPI on port 80 (default) |
| `delatometry-vpn.service` | Optional VPN on boot (`/etc/delatometry/vpn.json`) |

## Environment

`/etc/default/delatometry` is sourced by `scripts/systemd/run_node.sh`. Typical variables:

- `DELATOMETRY_WORKSPACE`
- `DELATOMETRY_VENV`
- `ROS_DOMAIN_ID`
- Database credentials

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
  delatometry-measure-device delatometry-core delatometry-webui
```

The **Dashboard** page in the Web UI can start/stop/restart units when passwordless sudo is configured (`src/webui/scripts/install_sudoers.sh`).

## Boot order

VPN (if enabled) may start before webui. Database and sensor nodes should be up before **core**, which expects LTM control traffic and DB connectivity. Webui can start independently; it reconnects to ROS services when available.

## Core launch parameters

Core requires (for full experiment features):

- `enable_pwm_controller:=true`
- `enable_database_client:=true`
- `enable_program_scheduler:=true` (default on when PWM is enabled)

See `src/core/config/core.params.yaml` for watchdog, topic names, and PI gains.
