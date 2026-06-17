#!/usr/bin/env bash
# Delatometry one-click installer — run from repo root: bash scripts/install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/ros2_install.sh
source "$SCRIPT_DIR/lib/ros2_install.sh"
# ros2_install_source.sh is sourced from ros2_install.sh
# shellcheck source=lib/ros_target.sh
source "$SCRIPT_DIR/lib/ros_target.sh"

WORKSPACE="${WORKSPACE:-$(detect_workspace "$SCRIPT_DIR" || _install_die "Cannot find workspace (expected src/msgs under $(dirname "$SCRIPT_DIR"))")}"
ROS_DISTRO="${ROS_DISTRO:-}"
ROS_SETUP="${ROS_SETUP:-}"
OS_CODENAME="${OS_CODENAME:-}"
VENV_DIR="${VENV_DIR:-$HOME/venvs/ros2_delatometry_webui}"

DB_NAME="${DB_NAME:-exp}"
DB_USER="${DB_USER:-delatometry}"
DB_PASSWORD="${DB_PASSWORD:-delatometry}"

INSTALL_SERVICES="${INSTALL_SERVICES:-1}"
START_SERVICES="${START_SERVICES:-1}"
INSTALL_ROS="${INSTALL_ROS:-1}"
ENABLE_SPI="${ENABLE_SPI:-}"
START_PIGPIOD="${START_PIGPIOD:-1}"
INSTALL_WEBUI_SUDOERS="${INSTALL_WEBUI_SUDOERS:-1}"

# Non-interactive: INSTALL_MODE=scratch|rebuild
INSTALL_MODE="${INSTALL_MODE:-}"

ensure_not_root() {
  if [ "$(id -u)" -eq 0 ]; then
    _install_die "Run as a normal user with sudo (not as root). Example: bash scripts/install.sh"
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    _install_die "sudo is required for one-click install"
  fi
}

detect_raspberry_pi() {
  if [ -f /proc/device-tree/model ] && grep -qi raspberry /proc/device-tree/model 2>/dev/null; then
    return 0
  fi
  if grep -qi raspberry /proc/cpuinfo 2>/dev/null; then
    return 0
  fi
  return 1
}

detect_pi5() {
  local rev=""
  if [ -r /proc/cpuinfo ]; then
    rev="$(grep -i '^Revision' /proc/cpuinfo 2>/dev/null | awk -F: '{print $2}' | tr -d ' \t' | tr '[:upper:]' '[:lower:]')"
  fi
  case "$rev" in
    d04*|c04*) return 0 ;;
  esac
  if [ -f /proc/device-tree/model ] && grep -qi 'raspberry pi 5' /proc/device-tree/model 2>/dev/null; then
    return 0
  fi
  return 1
}

ensure_whiptail() {
  if command -v whiptail >/dev/null 2>&1; then
    return 0
  fi
  echo "[install] Installing whiptail for menu..."
  sudo apt update
  sudo apt install -y whiptail
}

show_menu() {
  if ! interactive_ui_enabled; then
    _install_die "No interactive UI. Set INSTALL_MODE=scratch or INSTALL_MODE=rebuild"
  fi
  ensure_whiptail
  local rc=0
  CHOICE=$(whiptail --title "Delatometry installer" --menu "Choose install mode" 18 74 4 \
    "scratch" "Full one-click: OS deps, ROS 2 (you pick version), DB, build" \
    "rebuild" "Rebuild ROS packages and restart services" \
    3>&1 1>&2 2>&3) || rc=$?
  whiptail_handle_cancel "$rc"
  [ -n "${CHOICE:-}" ] || _install_die "Install mode not selected"
  INSTALL_MODE="$CHOICE"
}

install_apt_packages() {
  _install_log "Installing base system packages (apt)..."
  sudo apt update
  sudo apt install -y \
    whiptail \
    curl \
    git \
    unzip \
    rsync \
    net-tools \
    wireless-tools \
    network-manager \
    python3 \
    python3-venv \
    python3-pip \
    python3-dev \
    build-essential \
    cmake \
    pkg-config \
    python3-serial \
    python3-psutil \
    python3-matplotlib \
    python3-pigpio \
    python3-spidev \
    python3-vcstool \
    python3-markdown \
    libasio-dev \
    libtinyxml2-dev \
    libtinyxml-dev \
    libsqlite3-dev \
    libyaml-dev \
    libacl1-dev \
    libeigen3-dev \
    liborocos-kdl-dev \
    pigpio \
    dnsmasq \
    mariadb-server \
    mariadb-client \
    libmariadb-dev \
    openvpn \
    sudo \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common

  _install_log "Installing ZeroTier (optional VPN)..."
  if curl -fsSL 'https://install.zerotier.com' | sudo bash; then
    if command -v zerotier-cli >/dev/null 2>&1; then
      _install_log "ZeroTier OK: $(zerotier-cli -v 2>/dev/null || zerotier-cli status 2>/dev/null | head -1)"
      sudo systemctl enable zerotier-one 2>/dev/null || true
    else
      _install_log "WARN: ZeroTier install finished but zerotier-cli not found"
    fi
  else
    _install_log "WARN: ZeroTier install failed (install manually if needed)"
  fi

  if command -v raspi-config >/dev/null 2>&1 || [ -f /usr/bin/raspi-config ]; then
    sudo apt install -y raspi-config || true
  fi
}

ensure_ros() {
  if [ -f "$ROS_SETUP" ]; then
    _install_log "ROS setup found: $ROS_SETUP"
    return 0
  fi

  if [ "${INSTALL_ROS}" = "1" ]; then
    ros2_install_apt "$ROS_SETUP" || true
    if [ -f "$ROS_SETUP" ]; then
      return 0
    fi
  fi

  local msg
  msg="ROS 2 ${ROS_DISTRO} was not found at:\n  $ROS_SETUP\n\n"
  msg+="Target: apt codename '${OS_CODENAME}' + ROS 2 ${ROS_DISTRO}\n\n"
  msg+="Re-run scratch install and pick the correct OS/ROS pair in the dialog,\n"
  msg+="or set ROS_TARGET=bookworm-jazzy (or OS_CODENAME + ROS_DISTRO).\n\n"
  msg+="Manual install: https://docs.ros.org/en/${ROS_DISTRO}/Installation.html"

  if [ -t 0 ] && command -v whiptail >/dev/null 2>&1; then
    whiptail --title "ROS 2 required" --msgbox "$msg" 18 72 || true
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
  rosdep install --from-paths src --ignore-src -r -y --rosdistro "$ROS_DISTRO" 2>/dev/null || \
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
  if [ -z "$ENABLE_SPI" ]; then
    if detect_raspberry_pi; then
      ENABLE_SPI=1
      _install_log "Raspberry Pi detected — enabling SPI via raspi-config"
    else
      ENABLE_SPI=0
    fi
  fi

  _install_log "Adding user to dialout, spi, gpio groups..."
  sudo usermod -aG dialout,spi,gpio "$USER" 2>/dev/null || true

  if [ "$ENABLE_SPI" = "1" ] && command -v raspi-config >/dev/null 2>&1; then
    _install_log "Enabling SPI (raspi-config)..."
    sudo raspi-config nonint do_spi 0 || true
  fi

  if detect_pi5; then
    START_PIGPIOD=0
    _install_log "Raspberry Pi 5 detected — heater PWM uses lgpio (stock pigpiod is unsupported)"
    sudo apt install -y python3-lgpio 2>/dev/null || true
    sudo systemctl disable --now pigpiod 2>/dev/null || true
    local boot_cfg=""
    for boot_cfg in /boot/firmware/config.txt /boot/config.txt; do
      if [ -f "$boot_cfg" ] && ! grep -q '^dtoverlay=pwm' "$boot_cfg" 2>/dev/null; then
        _install_log "Pi 5 PWM: add dtoverlay=pwm to $boot_cfg and reboot if heater PWM fails"
        break
      fi
    done
  elif detect_raspberry_pi; then
    sudo apt install -y python3-lgpio 2>/dev/null || true
  fi

  if [ "$START_PIGPIOD" = "1" ]; then
    _install_log "Enabling pigpiod (PWM GPIO on Pi 4 and earlier)..."
    sudo systemctl enable pigpiod 2>/dev/null || true
    sudo systemctl start pigpiod 2>/dev/null || true
  fi
}

setup_python_venv() {
  if [ -d "$VENV_DIR" ]; then
    _install_log "Using existing Python venv: $VENV_DIR"
  else
    _install_log "Creating Python venv: $VENV_DIR"
    python3 -m venv --system-site-packages "$VENV_DIR"
  fi
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

  python3 -m pip install spidev pigpio pipyadc matplotlib markdown lgpio 2>/dev/null || true
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
  chmod +x "$WORKSPACE/scripts/lib/"*.sh 2>/dev/null || true
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
  python3 -c "import fastapi, uvicorn, jinja2; print('  fastapi OK')"
  [ -x "$WORKSPACE/install/webui/lib/webui/run.py" ] && echo "  webui run.py OK" \
    || _install_log "WARN: missing $WORKSPACE/install/webui/lib/webui/run.py"
  python3 -c "import mysql.connector; print('  mysql.connector OK')"
  python3 -c "import serial; print('  pyserial OK')"
  python3 -c "import psutil; print('  psutil OK')"
  python3 -c "import matplotlib; matplotlib.use('Agg'); print('  matplotlib OK')"
  _install_log "Verifying Python imports and tools..."
  python3 -c "import markdown; print('  markdown OK')"
  local _path_ext="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  PATH="$_path_ext:$PATH" command -v dnsmasq >/dev/null 2>&1 && echo "  dnsmasq OK" \
    || _install_log "WARN: dnsmasq not in PATH (hotspot DHCP will not work)"
  [ -f /etc/systemd/system/delatometry-hotspot-dnsmasq.service ] && echo "  hotspot-dnsmasq unit OK" \
    || _install_log "WARN: delatometry-hotspot-dnsmasq.service not installed"
  PATH="$_path_ext:$PATH" command -v openvpn >/dev/null 2>&1 && echo "  openvpn OK" \
    || _install_log "WARN: openvpn not in PATH"
  PATH="$_path_ext:$PATH" command -v zerotier-cli >/dev/null 2>&1 && echo "  zerotier-cli OK" \
    || _install_log "WARN: zerotier-cli not in PATH (Configuration → VPN → ZeroTier)"
  [ -f "$ROS_SETUP" ] && echo "  ROS setup OK ($ROS_SETUP)" \
    || _install_log "WARN: ROS setup missing"
}

install_systemd_services() {
  [ "$INSTALL_SERVICES" = "1" ] || return 0
  _install_log "Installing systemd service units..."
  START_SERVICES="$START_SERVICES" \
  ENABLE_SERVICES=1 \
  WORKSPACE="$WORKSPACE" \
  ROS_SETUP="$ROS_SETUP" \
  ROS_DISTRO="$ROS_DISTRO" \
  OS_CODENAME="$OS_CODENAME" \
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
    delatometry-im3536.service \
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
  select_ros_target scratch

  if interactive_ui_enabled; then
    local rc=0
    whiptail --title "Full one-click install" --msgbox \
      "This will install:\n  • System packages (MariaDB, pigpio, Python, …)\n  • ROS 2 ${ROS_DISTRO} on apt target ${OS_CODENAME} (if missing)\n  • Python venv + pip requirements\n  • colcon build all Delatometry packages\n  • systemd units + webui sudoers\n  • start services\n\nWorkspace:\n  $WORKSPACE" \
      20 74 || rc=$?
    whiptail_handle_cancel "$rc"
  fi

  install_apt_packages
  setup_python_venv
  ensure_ros
  init_rosdep
  setup_mariadb
  setup_hardware_groups
  install_pip_requirements
  set_executable_bits
  colcon_build_all 1
  verify_installation
  install_systemd_services
  install_webui_sudoers
}

run_rebuild_install() {
  select_ros_target rebuild

  if interactive_ui_enabled; then
    local rc=0
    whiptail --title "Rebuild" --msgbox \
      "ROS target: ${OS_CODENAME} + ROS 2 ${ROS_DISTRO}\n\nRebuild packages, refresh systemd, restart services.\n\nWorkspace:\n  $WORKSPACE" \
      14 70 || rc=$?
    whiptail_handle_cancel "$rc"
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
  echo " ROS target: ${OS_CODENAME} + ROS 2 ${ROS_DISTRO}"
  echo " ROS setup:  $ROS_SETUP"
  echo " Config:     /etc/default/delatometry"
  echo " Web UI:     http://$(hostname -I 2>/dev/null | awk '{print $1}')/"
  echo " Docs:       http://$(hostname -I 2>/dev/null | awk '{print $1}')/docs"
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
  ensure_not_root
  _install_log "Workspace: $WORKSPACE"
  _install_log "INSTALL_ROS=$INSTALL_ROS (ROS target chosen after mode selection)"

  if [ -z "$INSTALL_MODE" ]; then
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

  if interactive_ui_enabled; then
    whiptail --title "Done" --msgbox "Install completed successfully.\n\nWeb UI: http://<device-ip>/\nDocumentation: /docs\n\nUse scripts/systemd/status.sh to check services." 14 64 || true
  fi
}

main "$@"
