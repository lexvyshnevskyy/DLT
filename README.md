# Delatometry (ROS 2)

Temperature-programmed experiments on Linux / Raspberry Pi: **core** runs programs and PI control; **MariaDB** stores results; **web UI** and **Nextion HMI** operate the system.

## Quick start

```bash
cd ~/ros2_delatometry
bash scripts/install.sh
```

Requires **ROS 2 Jazzy**. After install: `http://<device-ip>/`  
Config: `/etc/default/delatometry`

Non-interactive install:

```bash
INSTALL_MODE=scratch bash scripts/install.sh
INSTALL_MODE=rebuild bash scripts/install.sh
```

## Documentation

| Language | Repository | Web UI (after `colcon build webui`) |
|----------|------------|-------------------------------------|
| English | [docs/en/](docs/en/) | [/docs/en](http://localhost/docs/en) |
| Ukrainian | [docs/uk/](docs/uk/) | [/docs/uk](http://localhost/docs/uk) |

Topics: overview, architecture, installation, systemd services, core, database, webui, HMI, hardware, troubleshooting, development.

Open **Documentation** in the site header (locale picks `/docs/en` or `/docs/uk`).

## Packages (`src/`)

| Package | Role |
|---------|------|
| [core](src/core/) | Programs, PI/PWM, measurement logging |
| [webui](src/webui/) | FastAPI browser HMI |
| [database](src/database/) | MariaDB ROS node |
| [hmi](src/hmi/) | Nextion serial display |
| [ltm2985_uart](src/ltm2985_uart/) | LTM2985 driver |
| [measure_device](src/measure_device/) | External measurements |
| [ads1256](src/ads1256/) | Optional ADC |
| [msgs](src/msgs/) | Interfaces |

## Operations

```bash
scripts/systemd/status.sh
scripts/systemd/logs.sh all
sudo systemctl restart delatometry-core delatometry-webui
```

## Legacy notes

Older material under `documents/` (deploy, Docker, UART) is kept for reference; prefer **`docs/`** for current ROS 2 stack behavior.

## License

See repository and submodule licenses per package.
