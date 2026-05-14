#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${WORKSPACE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ROS_SETUP="${ROS_SETUP:-/opt/ros/jazzy/setup.bash}"
VENV_DIR="${VENV_DIR:-$HOME/venvs/ros2_delatometry_webui}"

INSTALL_SERVICES="${INSTALL_SERVICES:-1}"
START_SERVICES="${START_SERVICES:-1}"
CLEAN_BUILD="${CLEAN_BUILD:-1}"
ENABLE_SPI="${ENABLE_SPI:-0}"
START_PIGPIOD="${START_PIGPIOD:-1}"

DB_NAME="${DB_NAME:-exp}"
DB_USER="${DB_USER:-delatometry}"
DB_PASSWORD="${DB_PASSWORD:-delatometry}"

echo "=== Delatometry one-click install ==="
echo "workspace:       $WORKSPACE"
echo "ROS setup:       $ROS_SETUP"
echo "venv:            $VENV_DIR"
echo "install services: $INSTALL_SERVICES"
echo "start services:   $START_SERVICES"

if [ ! -f "$ROS_SETUP" ]; then
  echo "ERROR: ROS setup file not found: $ROS_SETUP"
  echo "Install/source ROS 2 Jazzy first, or run with ROS_SETUP=/path/to/setup.bash"
  exit 1
fi

echo "[install] apt dependencies"
sudo apt update
sudo apt install -y \
  python3-venv \
  python3-pip \
  python3-dev \
  build-essential \
  python3-colcon-common-extensions \
  python3-serial \
  python3-psutil \
  python3-pigpio \
  python3-spidev \
  pigpio \
  default-mysql-server \
  default-mysql-client \
  mariadb-server \
  wireless-tools \
  net-tools \
  git \
  curl \
  unzip \
  raspi-config || true

echo "[install] enable MariaDB"
sudo systemctl enable mariadb || true
sudo systemctl start mariadb || true

echo "[install] configure database/user"
sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';

-- Compatibility user for older configs. Safe to leave unused.
CREATE USER IF NOT EXISTS 'ubuntu'@'localhost' IDENTIFIED BY '';
CREATE USER IF NOT EXISTS 'ubuntu'@'127.0.0.1' IDENTIFIED BY '';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO 'ubuntu'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO 'ubuntu'@'127.0.0.1';

FLUSH PRIVILEGES;
SQL

if [ "$ENABLE_SPI" = "1" ] && command -v raspi-config >/dev/null 2>&1; then
  echo "[install] enabling SPI"
  sudo raspi-config nonint do_spi 0 || true
fi

if [ "$START_PIGPIOD" = "1" ]; then
  echo "[install] enable pigpiod"
  sudo systemctl enable pigpiod || true
  sudo systemctl start pigpiod || true
fi

echo "[install] user serial/spi/gpio groups"
sudo usermod -aG dialout,spi,gpio "$USER" || true

echo "[install] venv dependencies"
python3 -m venv --system-site-packages "$VENV_DIR"
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install -U colcon-common-extensions

# Install package-local requirements.
for req in \
  "$WORKSPACE/src/webui/requirements.txt" \
  "$WORKSPACE/src/database/requirements.txt" \
  "$WORKSPACE/src/measure_device/requirements.txt" \
  "$WORKSPACE/src/hmi/requirements.txt" \
  "$WORKSPACE/src/ads1256/requirements.txt"
do
  if [ -f "$req" ]; then
    echo "[install] pip install -r $req"
    python3 -m pip install -r "$req"
  fi
done

echo "[install] source ROS"
set +u
# shellcheck disable=SC1090
source "$ROS_SETUP"
set -u

echo "[install] executable bits"
chmod +x "$WORKSPACE/src/core/core/run.py" || true
chmod +x "$WORKSPACE/src/database/database/run.py" || true
chmod +x "$WORKSPACE/src/webui/webui/run.py" || true
chmod +x "$WORKSPACE/src/ads1256/ads1256/run.py" || true
chmod +x "$WORKSPACE/scripts/systemd/"*.sh || true

if [ "$CLEAN_BUILD" = "1" ]; then
  echo "[install] clean build/install/log"
  rm -rf "$WORKSPACE/build" "$WORKSPACE/install" "$WORKSPACE/log"
fi

echo "[install] colcon build"
cd "$WORKSPACE"
python3 -m colcon build --symlink-install

echo "[install] source workspace"
set +u
# shellcheck disable=SC1090
source "$WORKSPACE/install/setup.bash"
set -u

echo "[install] verify key executables"
ros2 pkg executables database || true
ros2 pkg executables core || true
ros2 pkg executables ltm2985_uart || true
ros2 pkg executables measure_device || true
ros2 pkg executables ads1256 || true
ros2 pkg executables hmi || true
ros2 pkg executables webui || true

echo "[install] verify Python imports"
python3 -c "import rclpy; print('rclpy OK')"
python3 -c "from database.srv import Query; print('database/srv/Query OK')"
python3 -c "from msgs.msg import Measurement, E720, Ads; print('msgs OK')"
python3 -c "import gradio; print('gradio OK')"
python3 -c "import mysql.connector; print('mysql connector OK')"
python3 -c "import serial; print('pyserial OK')"

if [ "$INSTALL_SERVICES" = "1" ]; then
  echo "[install] install systemd services"
  START_SERVICES="$START_SERVICES" \
  WORKSPACE="$WORKSPACE" \
  ROS_SETUP="$ROS_SETUP" \
  VENV_DIR="$VENV_DIR" \
  DB_NAME="$DB_NAME" \
  DB_USER="$DB_USER" \
  DB_PASSWORD="$DB_PASSWORD" \
    "$WORKSPACE/scripts/systemd/install_services.sh"
fi

echo
echo "=== Delatometry install complete ==="
echo
echo "Config file:"
echo "  /etc/default/delatometry"
echo
echo "Service status:"
echo "  $WORKSPACE/scripts/systemd/status.sh"
echo
echo "Logs:"
echo "  $WORKSPACE/scripts/systemd/logs.sh all"
echo
echo "NOTE: if this install newly added the user to dialout/spi/gpio, reboot before hardware access:"
echo "  sudo reboot"
