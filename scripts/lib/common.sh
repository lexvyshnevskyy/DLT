#!/usr/bin/env bash
# Shared helpers for Delatometry installer (scripts/install.sh).

_install_log() {
  echo "[$(date '+%H:%M:%S')] $*"
}

_install_die() {
  echo "ERROR: $*" >&2
  exit 1
}

detect_workspace() {
  local script_dir="$1"
  if [ -f "$script_dir/../src/msgs/package.xml" ]; then
    cd "$script_dir/.." && pwd
    return 0
  fi
  return 1
}

source_ros() {
  local setup="$1"
  [ -f "$setup" ] || _install_die "ROS setup not found: $setup"
  set +u
  # shellcheck disable=SC1090
  source "$setup"
  set -u
}

source_workspace() {
  local ws="$1"
  [ -f "$ws/install/setup.bash" ] || _install_die "Workspace not built: $ws/install/setup.bash"
  set +u
  # shellcheck disable=SC1090
  source "$ws/install/setup.bash"
  set -u
}

activate_venv() {
  local venv_dir="$1"
  if [ -d "$venv_dir" ]; then
    set +u
    # shellcheck disable=SC1091
    source "$venv_dir/bin/activate"
    set -u
  fi
}

COLCON_PACKAGES=(
  msgs
  database
  core
  ltm2985_uart
  measure_device
  ads1256
  hmi
  webui
)
