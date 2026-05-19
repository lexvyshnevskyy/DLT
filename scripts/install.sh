#!/usr/bin/env bash
# Delatometry project installer — run from repo root: bash scripts/install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

WORKSPACE="${WORKSPACE:-$(detect_workspace "$SCRIPT_DIR" || _install_die "Cannot find workspace (expected src/msgs under $(dirname "$SCRIPT_DIR"))")}"
ROS_SETUP="${ROS_SETUP:-/opt/ros/jazzy/setup.bash}"
VENV_DIR="${VENV_DIR:-$HOME/venvs/ros2_delatometry_webui}"

DB_NAME="${DB_NAME:-exp}"
DB_USER="${DB_USER:-delatometry}"
DB_PASSWORD="${DB_PASSWORD:-delatometry}"

INSTALL_SERVICES="${INSTALL_SERVICES:-1}"
START_SERVICES="${START_SERVICES:-1}"
ENABLE_SPI="${ENABLE_SPI:-0}"
START_PIGPIOD="${START_PIGPIOD:-1}"
INSTALL_WEBUI_SUDOERS="${INSTALL_WEBUI_SUDOERS:-1}"

# Non-interactive: INSTALL_MODE=scratch|rebuild
INSTALL_MODE="${INSTALL_MODE:-}"

ensure_whiptail() {
  if command -v whiptail >/dev/null 2>&1; then
    return 0
  fi
  echo "[install] Installing whiptail for menu..."
  sudo apt update
  sudo apt install -y whiptail
}

show_menu() {
  ensure_whiptail
  CHOICE=$(whiptail --title "Delatometry installer" --menu "Choose install mode" 16 72 4 \
    "scratch" "Full install from scratch (OS deps, DB, build, services)" \
    "rebuild" "Rebuild all ROS packages and restart services" \
    3>&1 1>&2 2>&3) || exit 0
  INSTALL_MODE="$CHOICE"
}

install_apt_packages() {
  _install_log "Installing system packages (apt)..."
  sudo apt update
  sudo apt install -y \
    whiptail \
    curl \
    git \
    unzip \
    net-tools \
    wireless-tools \
    network-manager \
    python3 \
    python3-venv \
    python3-pip \
    python3-dev \
    build-essential \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-serial \
    python3-psutil \
    python3-pigpio \
    python3-spidev \
    pigpio \
    mariadb-server \
    mariadb-client \
    default-mysql-server \
    default-mysql-client \
    ros-dev-tools || true

  if command -v raspi-config >/dev/null 2>&1 || [ -f /usr/bin/raspi-config ]; then
    sudo apt install -y raspi-config || true
  fi
}

ensure_ros() {
  if [ -f "$ROS_SETUP" ]; then
    _install_log "ROS setup found: $ROS_SETUP"
    return 0
  fi

  local msg
  msg="ROS 2 Jazzy was not found at:\n  $ROS_SETUP\n\n"
  msg+="Install ROS 2 Jazzy first (Ubuntu 24.04 / RPi Bookworm):\n"
  msg+="  https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debians.html\n\n"
  msg+="Then re-run this installer, or set:\n  ROS_SETUP=/path/to/setup.bash"

  if [ -t 0 ] && command -v whiptail >/dev/null 2>&1; then
    whiptail --title "ROS 2 required" --msgbox "$msg" 16 72 || true
  else
    echo -e "$msg"
  fi
  _install_die "ROS setup missing"
}

init_rosdep() {
  if ! command -v rosdep >/dev/null 2>&1; then
    _install_log "rosdep not available, skipping"
    return 0
  fi
  if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    _install_log "Initializing rosdep (may need sudo)..."
    sudo rosdep init 2>/dev/null || true
  fi
  rosdep update 2>/dev/null || true
  _install_log "Installing rosdep keys for workspace packages..."
  cd "$WORKSPACE"
  rosdep install --from-paths src --ignore-src -r -y --rosdistro jazzy 2>/dev/null || \
    rosdep install --from-paths src --ignore-src -r -y 2>/dev/null || \
    _install_log "rosdep install finished with warnings (continuing)"
}

setup_mariadb() {
  _install_log "Configuring MariaDB database and user..."
  sudo systemctl enable mariadb 2>/dev/null || true
  sudo systemctl start mariadb 2>/dev/null || true

  sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
CREATE USER IF NOT EXISTS 'ubuntu'@'localhost' IDENTIFIED BY '';
CREATE USER IF NOT EXISTS 'ubuntu'@'127.0.0.1' IDENTIFIED BY '';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO 'ubuntu'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO 'ubuntu'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
}

setup_hardware_groups() {
  _install_log "Adding user to dialout, spi, gpio groups..."
  sudo usermod -aG dialout,spi,gpio "$USER" 2>/dev/null || true

  if [ "$ENABLE_SPI" = "1" ] && command -v raspi-config >/dev/null 2>&1; then
    _install_log "Enabling SPI (raspi-config)..."
    sudo raspi-config nonint do_spi 0 || true
  fi

  if [ "$START_PIGPIOD" = "1" ]; then
    _install_log "Enabling pigpiod..."
    sudo systemctl enable pigpiod 2>/dev/null || true
    sudo systemctl start pigpiod 2>/dev/null || true
  fi
}

setup_python_venv() {
  _install_log "Creating Python venv: $VENV_DIR"
  python3 -m venv --system-site-packages "$VENV_DIR"
  activate_venv "$VENV_DIR"
  python3 -m pip install --upgrade pip setuptools wheel
  python3 -m pip install -U colcon-common-extensions
}

install_pip_requirements() {
  _install_log "Installing Python requirements for all nodes..."
  activate_venv "$VENV_DIR"

  local req
  while IFS= read -r req; do
    [ -f "$req" ] || continue
    _install_log "pip install -r $req"
    python3 -m pip install -r "$req"
  done < <(find "$WORKSPACE/src" -name requirements.txt -type f 2>/dev/null | sort -u)

  python3 -m pip install spidev pigpio pipyadc 2>/dev/null || true
}

set_executable_bits() {
  _install_log "Setting executable bits on node entrypoints..."
  local f
  for f in \
    "$WORKSPACE/src/core/core/run.py" \
    "$WORKSPACE/src/database/database/run.py" \
    "$WORKSPACE/src/database/database_node/run.py" \
    "$WORKSPACE/src/webui/webui/run.py" \
    "$WORKSPACE/src/ads1256/ads1256/run.py" \
    "$WORKSPACE/src/hmi/hmi_rs232/run.py"
  do
    [ -f "$f" ] && chmod +x "$f" || true
  done
  chmod +x "$WORKSPACE/scripts/"*.sh 2>/dev/null || true
  chmod +x "$WORKSPACE/scripts/systemd/"*.sh 2>/dev/null || true
  chmod +x "$WORKSPACE/src/webui/scripts/install_sudoers.sh" 2>/dev/null || true
}

colcon_build_all() {
  local clean="${1:-0}"
  _install_log "Building ROS 2 packages: ${COLCON_PACKAGES[*]}"
  cd "$WORKSPACE"
  source_ros "$ROS_SETUP"
  activate_venv "$VENV_DIR"

  if [ "$clean" = "1" ]; then
    _install_log "Cleaning build, install, log directories..."
    rm -rf "$WORKSPACE/build" "$WORKSPACE/install" "$WORKSPACE/log"
  fi

  python3 -m colcon build --symlink-install --packages-select "${COLCON_PACKAGES[@]}"
}

verify_installation() {
  _install_log "Verifying build and imports..."
  source_ros "$ROS_SETUP"
  activate_venv "$VENV_DIR"
  source_workspace "$WORKSPACE"

  local pkg
  for pkg in "${COLCON_PACKAGES[@]}"; do
    ros2 pkg prefix "$pkg" >/dev/null 2>&1 || _install_log "WARN: package not found: $pkg"
  done

  python3 -c "import rclpy; print('  rclpy OK')"
  python3 -c "from database.srv import Query; print('  database/srv/Query OK')"
  python3 -c "from msgs.msg import Measurement, E720, Ads; print('  msgs OK')"
  python3 -c "import gradio; print('  gradio OK')"
  python3 -c "import mysql.connector; print('  mysql.connector OK')"
  python3 -c "import serial; print('  pyserial OK')"
  python3 -c "import psutil; print('  psutil OK')"
}

install_systemd_services() {
  [ "$INSTALL_SERVICES" = "1" ] || return 0
  _install_log "Installing systemd service units..."
  START_SERVICES="$START_SERVICES" \
  ENABLE_SERVICES=1 \
  WORKSPACE="$WORKSPACE" \
  ROS_SETUP="$ROS_SETUP" \
  VENV_DIR="$VENV_DIR" \
  DB_NAME="$DB_NAME" \
  DB_USER="$DB_USER" \
  DB_PASSWORD="$DB_PASSWORD" \
    "$WORKSPACE/scripts/systemd/install_services.sh"
}

install_webui_sudoers() {
  [ "$INSTALL_WEBUI_SUDOERS" = "1" ] || return 0
  local sudoers_script="$WORKSPACE/src/webui/scripts/install_sudoers.sh"
  if [ -f "$sudoers_script" ]; then
    _install_log "Installing webui sudoers (optional)..."
    sudo RUN_USER="$USER" bash "$sudoers_script" 2>/dev/null || \
      _install_log "WARN: sudoers install skipped (run manually if needed)"
  fi
}

restart_all_services() {
  [ "$START_SERVICES" = "1" ] || return 0
  _install_log "Restarting delatometry services..."
  local svc
  for svc in \
    delatometry-database.service \
    delatometry-ltm2985.service \
    delatometry-measure-device.service \
    delatometry-ads1256.service \
    delatometry-core.service \
    delatometry-hmi.service \
    delatometry-webui.service
  do
    sudo systemctl restart "$svc" 2>/dev/null || _install_log "WARN: could not restart $svc"
    sleep 1
  done
}

run_scratch_install() {
  if [ -t 0 ] && command -v whiptail >/dev/null 2>&1; then
    whiptail --title "Full install" --msgbox \
      "This will install system packages, MariaDB, Python venv, build all Delatometry nodes, install systemd units, and start services.\n\nWorkspace:\n  $WORKSPACE" \
      14 70 || exit 0
  fi

  install_apt_packages
  ensure_ros
  init_rosdep
  setup_mariadb
  setup_hardware_groups
  setup_python_venv
  install_pip_requirements
  set_executable_bits
  colcon_build_all 1
  verify_installation
  install_systemd_services
  install_webui_sudoers
}

run_rebuild_install() {
  if [ -t 0 ] && command -v whiptail >/dev/null 2>&1; then
    whiptail --title "Rebuild" --msgbox \
      "This will rebuild all ROS packages, refresh systemd units, and restart services.\n\nWorkspace:\n  $WORKSPACE" \
      12 70 || exit 0
  fi

  ensure_ros
  if [ -d "$VENV_DIR" ]; then
    activate_venv "$VENV_DIR"
  else
    setup_python_venv
  fi
  install_pip_requirements
  set_executable_bits
  colcon_build_all 0
  verify_installation
  install_systemd_services
  restart_all_services
}

print_summary() {
  echo
  echo "=============================================="
  echo " Delatometry install finished ($INSTALL_MODE)"
  echo "=============================================="
  echo " Workspace:  $WORKSPACE"
  echo " Config:     /etc/default/delatometry"
  echo " Web UI:     http://$(hostname -I 2>/dev/null | awk '{print $1}')/"
  echo " Status:     $WORKSPACE/scripts/systemd/status.sh"
  echo " Logs:       $WORKSPACE/scripts/systemd/logs.sh all"
  echo
  if [ "$INSTALL_MODE" = "scratch" ]; then
    echo " If serial/SPI/GPIO access fails, reboot once:"
    echo "   sudo reboot"
  fi
  echo "=============================================="
}

main() {
  _install_log "Workspace: $WORKSPACE"
  if [ -z "$INSTALL_MODE" ]; then
    if [ ! -t 0 ]; then
      _install_die "No TTY for interactive menu. Set INSTALL_MODE=scratch or INSTALL_MODE=rebuild"
    fi
    show_menu
  fi

  case "$INSTALL_MODE" in
    scratch|full|1)
      INSTALL_MODE=scratch
      run_scratch_install
      ;;
    rebuild|2)
      INSTALL_MODE=rebuild
      run_rebuild_install
      ;;
    *)
      _install_die "Unknown INSTALL_MODE=$INSTALL_MODE (use scratch or rebuild)"
      ;;
  esac

  print_summary

  if [ -t 0 ] && command -v whiptail >/dev/null 2>&1; then
    whiptail --title "Done" --msgbox "Install completed successfully.\n\nWeb UI: http://<device-ip>/\n\nUse scripts/systemd/status.sh to check services." 12 60 || true
  fi
}

main "$@"
