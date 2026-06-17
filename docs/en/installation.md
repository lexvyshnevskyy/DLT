# Installation

## One-click install (recommended)

On a **fresh Ubuntu 24.04** machine (including Raspberry Pi images based on Noble):

```bash
cd ~/ros2_delatometry
bash scripts/install.sh
```

Choose **Full one-click** (scratch). You will then pick the **OS codename + ROS 2 distro** (e.g. **Debian Bookworm + Jazzy** on a Pi OS test board). The script installs:

| Step | What |
|------|------|
| apt | MariaDB, pigpio, Python, build tools, VPN helpers |
| ROS 2 | Selected pair from dialog (e.g. `bookworm` + `jazzy`) via official apt |
| rosdep | Workspace dependencies |
| DB | Database `exp`, user `delatometry` |
| Python | venv + all `src/*/requirements.txt` |
| colcon | All 8 Delatometry packages |
| systemd | Services enabled and started |
| sudoers | Web UI service control (optional) |

Non-interactive (CI / SSH):

```bash
INSTALL_MODE=scratch bash scripts/install.sh
INSTALL_MODE=rebuild bash scripts/install.sh
```

Run as a **normal user with sudo** (not root).

## Requirements

| Item | Version / notes |
|------|-----------------|
| OS | Ubuntu 24.04, Debian 12 Bookworm (Pi OS), etc. — pick matching target in dialog |
| ROS 2 | Jazzy (Noble/Bookworm), Humble (Jammy), Rolling, Kilted — `/opt/ros/<distro>/setup.bash` |
| Database | MariaDB (installed by scratch mode) |
| Python | 3.10+; venv `~/venvs/ros2_delatometry_webui` |
| Hardware | LTM2985 UART; optional measure device / ADS1256 |

**Bookworm test board:** choose **Debian 12 Bookworm + ROS 2 Jazzy** (pre-selected when the installer detects `bookworm`).

## Installer environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `INSTALL_MODE` | (menu) | `scratch` or `rebuild` |
| `ROS_TARGET` | (dialog / auto) | Profile: `bookworm-jazzy`, `noble-jazzy`, `jammy-humble`, … |
| `OS_CODENAME` | (from profile) | Apt codename for ros-apt-source: `bookworm`, `noble`, `jammy` |
| `ROS_DISTRO` | (from profile) | `jazzy`, `humble`, `rolling`, `kilted` |
| `INSTALL_ROS` | `1` | Auto-install ROS 2 when missing |
| `ROS_SETUP` | `/opt/ros/<distro>/setup.bash` | ROS setup script path |
| `WORKSPACE` | auto-detect | Colcon workspace root |
| `VENV_DIR` | `~/venvs/ros2_delatometry_webui` | Web UI Python venv |
| `DB_NAME` / `DB_USER` / `DB_PASSWORD` | `exp` / `delatometry` / `delatometry` | MariaDB |
| `INSTALL_SERVICES` | `1` | Install systemd units |
| `START_SERVICES` | `1` | Start services after install |
| `START_PIGPIOD` | `1` | Enable pigpiod for PWM GPIO |
| `ENABLE_SPI` | auto on Pi | `raspi-config` SPI enable |
| `INSTALL_WEBUI_SUDOERS` | `1` | Dashboard systemctl via sudo |

Non-interactive Bookworm example:

```bash
ROS_TARGET=bookworm-jazzy INSTALL_MODE=scratch bash scripts/install.sh
```

Or explicit:

```bash
OS_CODENAME=bookworm ROS_DISTRO=jazzy INSTALL_MODE=scratch bash scripts/install.sh
```

Saved in `/etc/default/delatometry` as `DELATOMETRY_OS_CODENAME` and `DELATOMETRY_ROS_DISTRO` for rebuilds.

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
