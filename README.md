# Delatometry (ROS 2)

Temperature-programmed experiments on Linux / Raspberry Pi: **core** runs programs and PI control; **MariaDB** stores results; **web UI** and **Nextion HMI** operate the system.

## One-click install

On **Raspberry Pi OS Bookworm** or **Ubuntu 24.04**:

```bash
cd ~/ros2_delatometry
bash scripts/install.sh
```

**Full one-click** installs system packages, **ROS 2 Jazzy** (apt or source build on Pi), MariaDB, Python venv, builds all packages, and enables systemd services. Log: `~/delatometry_install.log`.

Non-interactive (headless Pi, ~30–90 min for ROS source build):

```bash
INSTALL_NONINTERACTIVE=1 INSTALL_MODE=scratch ROS_TARGET=bookworm-jazzy bash scripts/install.sh
INSTALL_MODE=rebuild bash scripts/install.sh
```

ROS-only (no Delatometry stack): `./install.sh` at repo root.

After install: `http://<device-ip>/` · Config: `/etc/default/delatometry`

On **Raspberry Pi**, the installer asks **Pi 4 vs Pi 5**, configures **2 GB swap**, **GPIO UART for HMI**, heater **PWM** (`pigpiod` on Pi 4, `lgpio` on Pi 5), and persistent run charts under `/var/lib/delatometry/run_charts`. Reboot once after the first install if prompted.

## Documentation

| Language | Repository | Web UI (after `colcon build webui`) |
|----------|------------|-------------------------------------|
| English | [docs/en/](docs/en/) | [/docs/en](http://localhost/docs/en) |
| Ukrainian | [docs/uk/](docs/uk/) | [/docs/uk](http://localhost/docs/uk) |

Topics: overview, architecture, installation, systemd services, core, database, webui, HMI, hardware, troubleshooting, development.

Open **Documentation** in the site header (locale picks `/docs/en` or `/docs/uk`).

## Impedance meter source

Choose **E7-20** (`measure_device`, `/e720`) or **IM3536** (`im3536`, `/im3536`) in Web UI **Configuration** or in `/etc/default/delatometry`:

```bash
DELATOMETRY_MEASURE_SOURCE=e720   # or im3536
```

E7-20 frequency sweeps in the program wizard apply only when the source is `e720`. IM3536 uses Hioki SCPI over RS-232, USB serial, or LAN (`delatometry-im3536.service`).

## Experiment modes

Stored in `program_meta.experiment_mode`:

| Mode | Heating | LTM in logs | Timing |
|------|---------|-------------|--------|
| `default` | Yes | Yes | LTM control-channel samples |
| `measure_only` | No | No | Fixed interval timer |
| `measure_ltm` | No | Yes | Fixed interval timer |

## Packages (`src/`)

| Package | Role |
|---------|------|
| [core](src/core/) | Programs, PI/PWM, measurement logging |
| [webui](src/webui/) | FastAPI browser HMI |
| [database](src/database/) | MariaDB ROS node |
| [hmi](src/hmi/) | Nextion serial display |
| [ltm2985_uart](src/ltm2985_uart/) | LTM2985 driver |
| [measure_device](src/measure_device/) | E7-20 impedance meter |
| [im3536](src/im3536/) | Hioki IM3536 LCR meter (RS-232 / USB / LAN) |
| [ads1256](src/ads1256/) | Optional ADC |
| [msgs](src/msgs/) | Interfaces |

## Operations

```bash
scripts/systemd/status.sh
scripts/systemd/logs.sh all
sudo systemctl restart delatometry-core delatometry-webui
```

## License

See repository and submodule licenses per package.
