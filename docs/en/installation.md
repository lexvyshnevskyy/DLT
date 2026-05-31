# Installation

## Requirements

| Item | Version / notes |
|------|-----------------|
| OS | Ubuntu / Debian (22.04+), Raspberry Pi OS supported |
| ROS 2 | **Jazzy** (`/opt/ros/jazzy/setup.bash`) |
| Database | MariaDB |
| Python | 3.10+; venv for webui (`DELATOMETRY_VENV`) |
| Hardware | LTM2985 UART, optional measure device / ADS1256 |

## Recommended: `scripts/install.sh`

From the workspace root:

```bash
cd ~/ros2_delatometry
bash scripts/install.sh
```

Interactive menu:

1. **Full install** — apt packages, MariaDB, Python venv, all `requirements.txt` under `src/`, `colcon build`, systemd units, optional sudoers for webui.
2. **Rebuild** — refresh build and restart services.

Non-interactive:

```bash
INSTALL_MODE=scratch bash scripts/install.sh
INSTALL_MODE=rebuild bash scripts/install.sh
```

Environment variables (examples):

| Variable | Purpose |
|----------|---------|
| `DELATOMETRY_WORKSPACE` | Workspace path (default `~/ros2_delatometry`) |
| `DELATOMETRY_VENV` | Web UI venv path |
| `DELATOMETRY_DB_*` | MariaDB name, user, password |

## After install

| Resource | Location |
|----------|----------|
| Env file | `/etc/default/delatometry` |
| Web UI | `http://<hostname-or-ip>/` |
| Service status | `scripts/systemd/status.sh` |
| Logs | `scripts/systemd/logs.sh all` |

## Manual build (developers)

```bash
source /opt/ros/jazzy/setup.bash
cd ~/ros2_delatometry
colcon build --symlink-install
source install/setup.bash
```

Single package:

```bash
colcon build --packages-select core webui database
```

## Python dependencies

Each package may ship `src/<pkg>/requirements.txt`. The root installer runs `pip install` for all of them. Web UI additionally needs packages listed in `src/webui/requirements.txt` (FastAPI, markdown, matplotlib, …).

## Deploying doc changes to a Pi

```bash
# sync workspace, then on the Pi:
cd ~/ros2_delatometry
colcon build --packages-select webui
pip install -r src/webui/requirements.txt   # if markdown was added
sudo systemctl restart delatometry-webui
```

Documentation is installed to `share/webui/docs/` and served at `/docs`.
