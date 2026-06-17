#!/usr/bin/env bash
# Build ROS 2 from source when distro packages are unavailable (e.g. Debian Bookworm arm64).

ros2_apt_package_exists() {
  local distro="$1"
  apt-cache show "ros-${distro}-ros-base" &>/dev/null
}

ros2_install_source() {
  local ros_setup="${1:-${ROS_SETUP:-}}"
  local distro="${ROS_DISTRO:-jazzy}"
  local ws="${ROS_SOURCE_WS:-$HOME/ros2_${distro}_ws}"

  ros_setup="${ws}/install/setup.bash"
  if [ -f "$ros_setup" ] && [ -d "${ws}/install/share/rosidl_default_generators" ]; then
    ROS_SETUP="$ros_setup"
    export ROS_SETUP
    _install_log "Using existing ROS 2 source build: $ROS_SETUP"
    return 0
  fi

  if [ -f "$ros_setup" ]; then
    _install_log "ROS setup exists but incomplete (rosidl_default_generators missing) — resuming build"
  fi

  _install_log "Building ROS 2 ${distro} from source at ${ws} (Bookworm has no binary ROS 2 packages)..."

  sudo apt update
  sudo apt install -y \
    build-essential \
    cmake \
    git \
    curl \
    wget \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool \
    python3-flake8-blind-except \
    python3-flake8-class-newline \
    python3-flake8-deprecated \
    python3-flake8-import-order \
    python3-flake8-quotes \
    python3-pytest-cov \
    python3-pytest-repeat \
    python3-pytest-rerunfailures \
    libacl1-dev \
    libeigen3-dev \
    liborocos-kdl-dev \
    libasio-dev \
    libtinyxml2-dev \
    libtinyxml-dev \
    libsqlite3-dev \
    libyaml-dev \
    libssl-dev \
    pkg-config \
    python3-lxml \
    liblttng-ust-dev \
    liblttng-ust1 \
    lttng-tools

  if ! command -v rosdep >/dev/null 2>&1; then
    _install_die "rosdep missing after apt install"
  fi
  if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    sudo rosdep init 2>/dev/null || true
  fi
  rosdep update 2>/dev/null || true

  mkdir -p "${ws}/src"
  cd "${ws}"
  if [ ! -f "${ws}/ros2.repos" ]; then
    curl -fsSL "https://raw.githubusercontent.com/ros2/ros2/${distro}/ros2.repos" -o "${ws}/ros2.repos"
  fi
  if [ ! -d "${ws}/src/ament" ]; then
    vcs import src < "${ws}/ros2.repos"
  fi

  _install_log "rosdep install for ROS 2 ${distro} source tree (may take a while)..."
  rosdep install --from-paths src --ignore-src -y --rosdistro "$distro" \
    --skip-keys "guixsd" 2>/dev/null || \
    rosdep install --from-paths src --ignore-src -y --skip-keys "guixsd" 2>/dev/null || \
    _install_log "WARN: rosdep finished with warnings"

  activate_venv "${VENV_DIR:-$HOME/venvs/ros2_delatometry_webui}"
  python3 -m pip install -U colcon-common-extensions vcstool lark 'empy==3.3.4' 2>/dev/null || true

  _install_log "colcon build ROS 2 ${distro} (30–90 min on Pi; go make coffee)..."
  cd "${ws}"
  export ROS_PYTHON_VERSION=3

  local -a skip_pkgs=(
    tracetools
    tracetools_trace
    lttngpy
    qt_gui_cpp
    rqt_gui
    rviz2
    rviz_default_plugins
    rviz_ogre_vendor
    orocos_kdl_vendor
    rmw_connextdds
    rmw_connextdds_common
    rmw_connextddsf_cpp
  )

  # Headless Pi: build only what Delatometry needs (not full desktop).
  local -a up_to_pkgs=(rclpy launch launch_ros message_filters)

  local rc=0
  _install_log "colcon --packages-up-to ${up_to_pkgs[*]} (minimal ROS 2 runtime)..."
  colcon build --merge-install --symlink-install \
    --packages-up-to "${up_to_pkgs[@]}" \
    --packages-skip "${skip_pkgs[@]}" \
    --cmake-args -DCMAKE_BUILD_TYPE=Release || rc=$?

  if [ "$rc" -ne 0 ] || [ ! -d "${ws}/install/share/rosidl_default_generators" ]; then
    _install_log "ROS minimal build incomplete (rc=${rc}); retrying full tree with skips..."
    colcon build --merge-install --symlink-install \
      --packages-skip "${skip_pkgs[@]}" \
      --cmake-args -DCMAKE_BUILD_TYPE=Release || rc=$?
  fi

  if [ ! -f "$ros_setup" ] || [ ! -d "${ws}/install/share/rosidl_default_generators" ]; then
    _install_die "ROS 2 source build incomplete — rosidl_default_generators missing (rc=${rc})"
  fi

  ROS_SETUP="$ros_setup"
  export ROS_SETUP
  _install_log "ROS 2 ${distro} source build ready: ${ROS_SETUP}"
}
