#!/usr/bin/env bash
# Build ROS 2 from source when distro packages are unavailable (e.g. Debian Bookworm arm64).
# Based on the repo-root install.sh manual flow (ros_base via rosinstall_generator).

ros2_apt_package_exists() {
  local distro="$1"
  apt-cache show "ros-${distro}-ros-base" &>/dev/null
}

ros2_source_workspace_dir() {
  local distro="${ROS_DISTRO:-jazzy}"
  local variant="${ROS_VARIANT:-ros_base}"
  echo "${ROS_SOURCE_WS:-$HOME/ros2_${distro}_${variant}_src}"
}

ros2_source_tool_venv() {
  echo "${ROS_BUILD_TOOL_VENV:-$HOME/.venvs/ros2-build-tools}"
}

ros2_source_already_built() {
  local ws="$1"
  [ -f "${ws}/install/setup.bash" ] && \
    [ -d "${ws}/install/share/rosidl_default_generators" ]
}

ros2_install_source() {
  local ros_setup="${1:-${ROS_SETUP:-}}"
  local distro="${ROS_DISTRO:-jazzy}"
  local variant="${ROS_VARIANT:-ros_base}"
  local ws
  ws="$(ros2_source_workspace_dir)"
  local tool_venv
  tool_venv="$(ros2_source_tool_venv)"
  local workers="${WORKERS:-1}"
  local rosdep_skip_keys="${ROSDEP_SKIP_KEYS:-rti-connext-dds-6.0.1 python3-catkin-pkg-modules python3-rospkg-modules python3-rosdistro-modules python3-vcstool}"

  ros_setup="${ws}/install/setup.bash"
  export ROS_BUILD_TOOL_VENV="$tool_venv"
  export ROS_SOURCE_WS="$ws"

  if ros2_source_already_built "$ws"; then
    ROS_SETUP="$ros_setup"
    export ROS_SETUP
    _install_log "Using existing ROS 2 source build: $ROS_SETUP"
    return 0
  fi

  if [ -f "$ros_setup" ]; then
    _install_log "ROS setup exists but incomplete (rosidl_default_generators missing) — rebuilding"
  fi

  _install_log "Building ROS 2 ${distro} (${variant}) from source at ${ws} (Pi/Bookworm flow)..."

  export LANG=C.UTF-8
  export LC_ALL=C.UTF-8

  sudo apt update
  sudo apt install -y \
    build-essential \
    cmake \
    git \
    curl \
    wget \
    gnupg2 \
    lsb-release \
    locales \
    ca-certificates \
    python3-dev \
    python3-venv \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    python3-numpy \
    python3-yaml \
    python3-empy \
    python3-lark \
    python3-packaging \
    python3-netifaces \
    python3-pytest \
    python3-pytest-cov \
    python3-argcomplete \
    python3-catkin-pkg \
    python3-rospkg \
    python3-rosdistro \
    libacl1-dev \
    libasio-dev \
    libcunit1-dev \
    libeigen3-dev \
    libtinyxml2-dev \
    libssl-dev \
    libsqlite3-dev \
    libyaml-dev \
    libyaml-cpp-dev \
    libcurl4-openssl-dev \
    libconsole-bridge-dev \
    libspdlog-dev \
    libfmt-dev \
    libgtest-dev

  sudo locale-gen en_US en_US.UTF-8 2>/dev/null || true
  sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 2>/dev/null || true
  if locale -a 2>/dev/null | grep -qi '^en_US\.utf8$'; then
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
  else
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
  fi

  mkdir -p "$(dirname "$tool_venv")"
  python3 -m venv "$tool_venv"
  "$tool_venv/bin/pip" install --upgrade pip setuptools wheel
  "$tool_venv/bin/pip" install --upgrade \
    colcon-common-extensions \
    vcstool \
    rosdep \
    rosinstall-generator \
    catkin-pkg \
    rospkg \
    rosdistro \
    numpy \
    PyYAML \
    empy \
    lark \
    packaging \
    netifaces

  export PATH="$tool_venv/bin:$PATH"

  if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    sudo "$tool_venv/bin/rosdep" init
  fi
  "$tool_venv/bin/rosdep" update --rosdistro "$distro"

  mkdir -p "${ws}/src"
  cd "$ws"

  "$tool_venv/bin/rosinstall_generator" "$variant" \
    --rosdistro "$distro" \
    --deps \
    --tar \
    > "${distro}-${variant}.repos"

  "$tool_venv/bin/vcs" import src < "${distro}-${variant}.repos"

  rm -rf src/ros2/rmw_connextdds

  local -a rosdep_skip_args=()
  if [ -n "$rosdep_skip_keys" ]; then
    rosdep_skip_args=(--skip-keys "$rosdep_skip_keys")
  fi

  _install_log "rosdep install for ROS 2 source tree (may take a while)..."
  "$tool_venv/bin/rosdep" install \
    --from-paths src \
    --ignore-src \
    --rosdistro "$distro" \
    -y \
    "${rosdep_skip_args[@]}"

  export CMAKE_BUILD_PARALLEL_LEVEL="$workers"
  export MAKEFLAGS="-j${workers}"

  _install_log "colcon build ROS 2 ${distro} (${variant}); workers=${workers} (long on Pi)..."
  "$tool_venv/bin/colcon" build \
    --merge-install \
    --symlink-install \
    --parallel-workers "$workers" \
    --event-handlers console_direct+ \
    --cmake-args \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_TESTING=OFF

  if ! ros2_source_already_built "$ws"; then
    _install_die "ROS 2 source build incomplete — missing install/setup.bash or rosidl_default_generators"
  fi

  set +u
  # shellcheck disable=SC1090
  source "$ros_setup"
  set -u
  ros2 --help >/dev/null
  python3 - <<'PY'
import rclpy
from std_msgs.msg import String
print("ROS 2 Python import OK")
PY

  local setup_line="source $ros_setup"
  if ! grep -qxF "$setup_line" "$HOME/.bashrc" 2>/dev/null; then
    {
      echo ""
      echo "# ROS 2 ${distro} from source (Delatometry installer)"
      echo "$setup_line"
    } >> "$HOME/.bashrc"
  fi

  ROS_SETUP="$ros_setup"
  export ROS_SETUP
  _install_log "ROS 2 ${distro} source build ready: ${ROS_SETUP}"
}
