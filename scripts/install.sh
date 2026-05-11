#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_not_root
ROS_DISTRO="$(resolve_ros_distro)"
log "Detected ROS distro: ${ROS_DISTRO}"

ensure_locale
ensure_ros_repo_and_tools "${ROS_DISTRO}"

sudo apt-get install -y \
  git openssh-client wget unzip rsync \
  build-essential cmake pkg-config \
  python3-pip python3-venv python3-dev python3-setuptools python3-wheel \
  python3-serial python3-psutil python3-numpy python3-mysql.connector python3-pigpio \
  pigpio mysql-server mysql-client

if ! python3 -c 'import mysql.connector' >/dev/null 2>&1; then
  python3 -m pip install --user mysql-connector-python
fi

python3 -m pip install --user --upgrade pip wheel setuptools
python3 -m pip install --user pyserial psutil gradio mysql-connector-python pipyadc pigpio

sudo systemctl enable --now pigpiod.service
sudo usermod -aG dialout,gpio "${USER}"

ensure_rosdep_initialized

WORKSPACE="$(workspace_root)"
write_env_file "${WORKSPACE}" "${ROS_DISTRO}" "${USER}"
configure_mysql

log "Base system installation complete."
log "Now run: ${SCRIPT_DIR}/setup_dlt.sh"
log "You may need to log out and back in once for new group membership (dialout/gpio) to apply."
C