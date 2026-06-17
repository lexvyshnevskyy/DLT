#!/usr/bin/env bash
# Install ROS 2 from apt, or from source when binaries are unavailable (Debian Bookworm).

# shellcheck source=ros2_install_source.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ros2_install_source.sh"

ros2_install_apt() {
  local ros_setup="${1:-${ROS_SETUP:-/opt/ros/jazzy/setup.bash}}"
  local distro="${ROS_DISTRO:-jazzy}"
  local codename="${OS_CODENAME:-}"

  if [ -f "$ros_setup" ]; then
    _install_log "ROS 2 already installed: $ros_setup"
    return 0
  fi

  if [ "${INSTALL_ROS:-1}" != "1" ]; then
    _install_log "INSTALL_ROS=0 — skipping automatic ROS 2 install"
    return 1
  fi

  if [ -z "$codename" ]; then
    . /etc/os-release
    codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  fi
  [ -n "$codename" ] || _install_die "OS_CODENAME is not set (use ROS target dialog or OS_CODENAME=bookworm)"

  _install_log "Installing ROS 2 ${distro} for apt codename '${codename}' (one-click)..."

  case "${codename}:${distro}" in
    bookworm:jazzy)
      _install_log "Target: Debian Bookworm + Jazzy (supported via ros-apt-source)"
      ;;
    noble:jazzy|noble:kilted)
      _install_log "Target: Ubuntu Noble + ${distro}"
      ;;
    jammy:humble)
      _install_log "Target: Ubuntu Jammy + Humble"
      ;;
    bookworm:rolling|bookworm:humble)
      _install_log "WARN: ${distro} on Bookworm may have limited binary support — apt will try official packages"
      ;;
    *)
      _install_log "WARN: Untested pair codename='${codename}' distro='${distro}' — continuing"
      ;;
  esac

  sudo apt update
  sudo apt install -y \
    curl \
    gnupg \
    lsb-release \
    ca-certificates \
    software-properties-common

  local ros_apt_ver deb url
  ros_apt_ver="$(
    curl -fsSL https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
      | grep -F '"tag_name"' \
      | head -1 \
      | sed -E 's/.*"([^"]+)".*/\1/'
  )"
  [ -n "$ros_apt_ver" ] || _install_die "Could not read ros-apt-source release version from GitHub"

  deb="/tmp/ros2-apt-source_${ros_apt_ver}.${codename}_all.deb"
  url="https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ros_apt_ver}/ros2-apt-source_${ros_apt_ver}.${codename}_all.deb"

  _install_log "Fetching ros-apt-source: $url"
  if ! curl -fsSL "$url" -o "$deb"; then
    _install_die "ros-apt-source not available for codename '${codename}'. Pick another target in the install dialog or install ROS manually."
  fi

  sudo dpkg -i "$deb" || sudo apt install -f -y
  sudo apt update

  if ! ros2_apt_package_exists "$distro"; then
    _install_log "No apt package ros-${distro}-ros-base for codename '${codename}' — using source build"
    if [ "${ROS_INSTALL_SOURCE_FALLBACK:-1}" = "1" ]; then
      ros2_install_source "$ros_setup"
      return $?
    fi
    _install_die "ROS 2 ${distro} binaries not available for ${codename}. Set ROS_INSTALL_SOURCE_FALLBACK=1 or pick another ROS target."
  fi

  _install_log "Installing ROS 2 ${distro} packages (may take several minutes)..."
  sudo apt install -y \
    "ros-${distro}-ros-base" \
    "ros-${distro}-message-filters" \
    "ros-${distro}-launch" \
    "ros-${distro}-launch-ros" \
    "ros-${distro}-rosidl-default-generators" \
    "ros-${distro}-ament-cmake" \
    "ros-${distro}-ament-cmake-python" \
    "ros-${distro}-ament-index-python" \
    "ros-${distro}-std-msgs" \
    "ros-${distro}-builtin-interfaces" \
    ros-dev-tools \
    python3-rosdep \
    python3-colcon-common-extensions

  if [ ! -f "$ros_setup" ]; then
    _install_die "ROS 2 ${distro} apt install finished but missing: $ros_setup"
  fi

  _install_log "ROS 2 ${distro} ready: $ros_setup (${codename})"
}

# Backward-compatible alias
ros2_install_jazzy() {
  ros2_install_apt "$@"
}
