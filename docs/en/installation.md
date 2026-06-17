# Installation

## One-click install (recommended)

On a **fresh Ubuntu 24.04** machine or **Raspberry Pi OS Bookworm**:

```bash
cd ~/ros2_delatometry
bash scripts/install.sh
```

Choose **Full one-click** (scratch). You will then pick the **OS codename + ROS 2 distro** (e.g. **Debian Bookworm + Jazzy** on Pi OS). On Raspberry Pi you also choose **Pi 4 vs Pi 5** for GPIO/PWM setup.

The script installs:

| Step | What |
|------|------|
| apt | MariaDB, Python, build tools, pigpio, dphys-swapfile, VPN helpers |
| Pi hardware | 2 GB swap, GPIO UART for HMI, SPI, Pi 4/5 PWM backend |
| ROS 2 | Selected pair from dialog (e.g. `bookworm` + `jazzy`) via official apt |
| rosdep | Workspace dependencies |
| DB | Database `exp`, user `delatometry` |
| Python | venv + all `src/*/requirements.txt` |
| colcon | All Delatometry packages |
| systemd | Services enabled and started; `/etc/default/delatometry` |
| sudoers | Web UI service control (optional) |

Non-interactive (CI / SSH):

```bash
INSTALL_NONINTERACTIVE=1 INSTALL_MODE=scratch ROS_TARGET=bookworm-jazzy bash scripts/install.sh
INSTALL_MODE=rebuild bash scripts/install.sh
```

Headless Pi 5 example:

```bash
INSTALL_NONINTERACTIVE=1 INSTALL_MODE=scratch ROS_TARGET=bookworm-jazzy RPI_MODEL=rpi5 bash scripts/install.sh
```

Run as a **normal user with sudo** (not root). **Reboot once** after the first Pi install if UART or Pi 5 PWM boot config changed.

## Raspberry Pi setup (installer)

| Feature | Pi 4 / Pi 3 / Zero 2 W | Pi 5 |
|---------|------------------------|------|
| Heater PWM | `pigpiod` + `pigpio` | `lgpio` (`python3-lgpio`) |
| `pigpiod` service | Enabled and started | Disabled and masked |
| Hardware PWM overlay | — | `dtoverlay=pwm` (prompt or auto) |
| Swap | 2 GB via `dphys-swapfile` | Same |
| HMI UART | GPIO 14/15; login shell off | Same (`raspi-config` + `enable_uart=1`) |
| Run charts | `/var/lib/delatometry/run_charts` | Same |

Saved in `/etc/default/delatometry`:

- `DELATOMETRY_RPI_MODEL` — `rpi4` or `rpi5`
- `DELATOMETRY_PWM_BACKEND` — `pigpio` or `lgpio`
- `DELATOMETRY_HMI_PORT` — e.g. `/dev/serial0` or `/dev/ttyAMA10`
- `DELATOMETRY_WEBUI_RUN_CHARTS_DIR` — persistent PNG charts for program runs

## Requirements

| Item | Version / notes |
|------|-----------------|
| OS | Ubuntu 24.04, Debian 12 Bookworm (Pi OS), etc. — pick matching target in dialog |
| ROS 2 | Jazzy (Noble/Bookworm), Humble (Jammy), Rolling, Kilted — `/opt/ros/<distro>/setup.bash` |
| Database | MariaDB (installed by scratch mode) |
| Python | 3.10+; venv `~/venvs/ros2_delatometry_webui` |
| Hardware | LTM2985 UART; optional measure device / ADS1256 / Nextion HMI |

**Bookworm test board:** choose **Debian 12 Bookworm + ROS 2 Jazzy** (pre-selected when the installer detects `bookworm`).

## Installer environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `INSTALL_MODE` | (menu) | `scratch` or `rebuild` |
| `INSTALL_NONINTERACTIVE` | `0` | Skip whiptail menus |
| `ROS_TARGET` | (dialog / auto) | Profile: `bookworm-jazzy`, `noble-jazzy`, `jammy-humble`, … |
| `OS_CODENAME` | (from profile) | Apt codename for ros-apt-source |
| `ROS_DISTRO` | (from profile) | `jazzy`, `humble`, `rolling`, `kilted` |
| `RPI_MODEL` / `DELATOMETRY_RPI_MODEL` | (dialog on Pi) | `rpi4` or `rpi5` |
| `SWAP_SIZE_MB` | `2048` | Raspberry Pi swap size |
| `ADD_PI5_PWM_OVERLAY` | `1` | Non-interactive: append `dtoverlay=pwm` on Pi 5 |
| `INSTALL_ROS` | `1` | Auto-install ROS 2 when missing |
| `WORKSPACE` | auto-detect | Colcon workspace root |
| `VENV_DIR` | `~/venvs/ros2_delatometry_webui` | Web UI Python venv |
| `DB_NAME` / `DB_USER` / `DB_PASSWORD` | `exp` / `delatometry` / `delatometry` | MariaDB |
| `INSTALL_SERVICES` | `1` | Install systemd units |
| `START_SERVICES` | `1` | Start services after install |
| `START_PIGPIOD` | `1` on Pi 4 | Overridden to `0` on Pi 5 |
| `ENABLE_SPI` | auto on Pi | `raspi-config` SPI enable |
| `INSTALL_WEBUI_SUDOERS` | `1` | Dashboard systemctl via sudo |
| `DELATOMETRY_WEBUI_RUN_CHARTS_DIR` | `/var/lib/delatometry/run_charts` | Persistent program-run chart PNGs |

Saved in `/etc/default/delatometry` as `DELATOMETRY_OS_CODENAME`, `DELATOMETRY_ROS_DISTRO`, and the Pi/PWM/HMI/chart variables above.

## After install

| Resource | Location |
|----------|----------|
| Env file | `/etc/default/delatometry` |
| Web UI | `http://<hostname-or-ip>/` |
| Run charts | `/var/lib/delatometry/run_charts` |
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

## Deploying updates to a Pi

```bash
cd ~/ros2_delatometry
git pull   # or sync workspace
colcon build --packages-select webui core
scripts/systemd/install_services.sh   # refresh env + units if needed
sudo systemctl restart delatometry-core delatometry-webui
```

Documentation is installed to `share/webui/docs/` and served at `/docs`.
