#!/usr/bin/env bash
# Connect VPN on boot when enabled in /etc/delatometry/vpn.json
set -euo pipefail

ENV_FILE="${ENV_FILE:-/etc/default/delatometry}"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

: "${DELATOMETRY_WORKSPACE:=$HOME/ros2_delatometry}"
: "${DELATOMETRY_ROS_SETUP:=/opt/ros/jazzy/setup.bash}"
: "${DELATOMETRY_VENV:=$HOME/venvs/ros2_delatometry_webui}"

[ -f /etc/delatometry/vpn.json ] || exit 0

set +u
# shellcheck disable=SC1090
source "$DELATOMETRY_ROS_SETUP" 2>/dev/null || true
if [ -d "$DELATOMETRY_VENV" ]; then
  # shellcheck disable=SC1090
  source "$DELATOMETRY_VENV/bin/activate"
fi
if [ -f "$DELATOMETRY_WORKSPACE/install/setup.bash" ]; then
  # shellcheck disable=SC1090
  source "$DELATOMETRY_WORKSPACE/install/setup.bash"
fi
set -u

exec python3 -c "from webui.collectors.vpn_config import vpn_boot_connect; vpn_boot_connect()"
