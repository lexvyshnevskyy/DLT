#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

require_bookworm

WORKSPACE_ROOT="$(repo_root_from_script)"
if [[ -z "$WORKSPACE_ROOT" ]]; then
  WORKSPACE_ROOT="$HOME/dlt"
fi
ENV_FILE="${DLT_ENV_FILE:-$DEFAULT_ENV_FILE}"
CALL_SETUP=1
if [[ "${1:-}" == "--no-project-setup" ]]; then
  CALL_SETUP=0
fi

log "Updating apt metadata"
sudo apt-get update

log "Installing base Bookworm packages"
apt_install \
  git openssh-client ca-certificates curl wget gnupg lsb-release locales \
  build-essential cmake ninja-build pkg-config unzip \
  python3 python3-dev python3-pip python3-venv python3-setuptools python3-wheel \
  python3-argcomplete python3-empy python3-lark python3-yaml python3-serial \
  python3-psutil python3-numpy python3-vcstool python3-rosdep2 python3-rosdistro \
  python3-colcon-common-extensions python3-colcon-ros python3-catkin-pkg-modules \
  python3-rospkg-modules libyaml-cpp-dev libasio-dev libtinyxml2-dev \
  libssl-dev libcurl4-openssl-dev libbenchmark-dev

log "Installing Debian ROS/ROS 2 packages available on Bookworm"
apt_install_if_available \
  ament-cmake ament-cmake-core ament-cmake-ros ament-cmake-python \
  python3-ament-package python3-ament-index python3-rclpy \
  python3-launch python3-launch-ros python3-message-filters \
  rosidl-cmake rosidl-tools rosidl-generator-c-cpp rosidl-generator-py \
  rosidl-default-generators rosidl-default-runtime \
  python3-std-msgs libstd-msgs-dev python3-builtin-interfaces libbuiltin-interfaces-dev \
  libament-index-cpp-dev librcutils-dev librcpputils-dev

log "Installing database packages"
apt_install default-mysql-server default-mysql-client

log "Configuring locale"
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

ensure_system_groups "$USER"
ensure_pigpio
ensure_env_file "$WORKSPACE_ROOT" "$ENV_FILE"
setup_database_from_env "$ENV_FILE"
rosdep_init_if_needed
install_project_python_packages

if [[ $CALL_SETUP -eq 1 && -x "$SCRIPT_DIR/setup_dlt.sh" ]]; then
  log "Calling setup_dlt.sh"
  "$SCRIPT_DIR/setup_dlt.sh"
else
  log "Base system install finished"
fi
