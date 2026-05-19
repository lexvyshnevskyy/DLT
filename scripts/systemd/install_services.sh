#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${WORKSPACE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
ENV_FILE="${ENV_FILE:-/etc/default/delatometry}"
START_SERVICES="${START_SERVICES:-1}"
ENABLE_SERVICES="${ENABLE_SERVICES:-1}"

if [ "$(id -u)" -eq 0 ]; then
  RUN_USER="${RUN_USER:-${SUDO_USER:-root}}"
else
  RUN_USER="${RUN_USER:-$USER}"
fi
RUN_GROUP="${RUN_GROUP:-$(id -gn "$RUN_USER")}"

ROS_SETUP="${ROS_SETUP:-/opt/ros/jazzy/setup.bash}"
VENV_DIR="${VENV_DIR:-$HOME/venvs/ros2_delatometry_webui}"

# Defaults are intentionally editable in /etc/default/delatometry after install.
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-exp}"
DB_USER="${DB_USER:-delatometry}"
DB_PASSWORD="${DB_PASSWORD:-delatometry}"

echo "[services] workspace: $WORKSPACE"
echo "[services] run user:  $RUN_USER:$RUN_GROUP"
echo "[services] env file:  $ENV_FILE"

sudo install -d -m 0755 "$(dirname "$ENV_FILE")"

if [ -f "$ENV_FILE" ]; then
  sudo cp "$ENV_FILE" "$ENV_FILE.bak.$(date +%Y%m%d_%H%M%S)"
fi

sudo tee "$ENV_FILE" >/dev/null <<EOF
# Delatometry system runtime configuration.
# Edit this file, then run:
#   sudo systemctl restart 'delatometry-*'

DELATOMETRY_WORKSPACE="$WORKSPACE"
DELATOMETRY_ROS_SETUP="$ROS_SETUP"
DELATOMETRY_VENV="$VENV_DIR"

# Database
DELATOMETRY_DB_HOST="$DB_HOST"
DELATOMETRY_DB_PORT="$DB_PORT"
DELATOMETRY_DB_NAME="$DB_NAME"
DELATOMETRY_DB_USER="$DB_USER"
DELATOMETRY_DB_PASSWORD="$DB_PASSWORD"
DELATOMETRY_DB_AUTO_INIT_SCHEMA="true"

# LTM2985 UART
DELATOMETRY_LTM2985_PORT="/dev/ttyUSB0"
DELATOMETRY_LTM2985_BAUDRATE="230400"

# E7-20 / measure_device
DELATOMETRY_MEASURE_PORT="/dev/ttyUSB0"
DELATOMETRY_MEASURE_SPEED="9600"

# ADS1256 (disabled by default — enable in webui Configuration when hardware is present)
DELATOMETRY_ADS1256_ENABLED="false"
DELATOMETRY_ADS1256_SIMULATE="false"
DELATOMETRY_ADS1256_FALLBACK_TO_SIMULATION="true"

# Core
DELATOMETRY_CORE_NAMESPACE="core"
DELATOMETRY_CORE_MEASUREMENT_TOPIC="/ltm2985/measurement"
DELATOMETRY_CORE_ENABLE_DATABASE_CLIENT="false"
DELATOMETRY_CORE_ENABLE_PWM_CONTROLLER="false"
DELATOMETRY_CORE_PWM_PIN_CH1="18"
DELATOMETRY_CORE_PWM_PIN_CH2="19"

# HMI serial display
DELATOMETRY_HMI_PORT="/dev/ttyS0"
DELATOMETRY_HMI_BAUDRATE="115200"
DELATOMETRY_HMI_DATABASE_REQUIRED="true"
DELATOMETRY_HMI_DATABASE_WAIT_TIMEOUT_SEC="30.0"
EOF

chmod +x "$WORKSPACE/scripts/systemd/run_node.sh"

write_unit() {
  local service_name="$1"
  local description="$2"
  local node_name="$3"
  local after="$4"
  local wants="$5"
  local requires="$6"
  local extra_service=""

  if [ "$node_name" = "webui" ]; then
    extra_service=$'AmbientCapabilities=CAP_NET_BIND_SERVICE\n'
  fi

  sudo tee "/etc/systemd/system/${service_name}.service" >/dev/null <<EOF
[Unit]
Description=$description
After=network-online.target $after
Wants=network-online.target $wants
Requires=$requires

[Service]
Type=simple
User=$RUN_USER
Group=$RUN_GROUP
WorkingDirectory=$WORKSPACE
EnvironmentFile=$ENV_FILE
ExecStart=$WORKSPACE/scripts/systemd/run_node.sh $node_name
Restart=on-failure
RestartSec=3
KillSignal=SIGINT
TimeoutStopSec=15
Environment=PYTHONUNBUFFERED=1
${extra_service}
[Install]
WantedBy=multi-user.target
EOF
}

write_unit "delatometry-database" \
  "Delatometry Database ROS 2 node" \
  "database" \
  "mariadb.service mysql.service" \
  "mariadb.service mysql.service" \
  ""

write_unit "delatometry-ltm2985" \
  "Delatometry LTM2985 UART ROS 2 node" \
  "ltm2985_uart" \
  "" \
  "" \
  ""

write_unit "delatometry-measure-device" \
  "Delatometry E7-20 Measure Device ROS 2 node" \
  "measure_device" \
  "" \
  "" \
  ""

write_unit "delatometry-ads1256" \
  "Delatometry ADS1256 ROS 2 node" \
  "ads1256" \
  "pigpiod.service" \
  "pigpiod.service" \
  ""

write_unit "delatometry-core" \
  "Delatometry Core ROS 2 node" \
  "core" \
  "delatometry-database.service delatometry-ltm2985.service" \
  "delatometry-database.service delatometry-ltm2985.service" \
  ""

write_unit "delatometry-hmi" \
  "Delatometry HMI ROS 2 node" \
  "hmi" \
  "delatometry-database.service delatometry-measure-device.service" \
  "delatometry-measure-device.service" \
  "delatometry-database.service"

# WebUI must not Require database/core — stopping those services from the UI
# would otherwise stop this unit too and kill the browser session.
write_unit "delatometry-webui" \
  "Delatometry WebUI ROS 2 node" \
  "webui" \
  "delatometry-database.service delatometry-core.service" \
  "delatometry-database.service delatometry-core.service" \
  ""

sudo systemctl daemon-reload

services=(
  delatometry-database.service
  delatometry-ltm2985.service
  delatometry-measure-device.service
  delatometry-ads1256.service
  delatometry-core.service
  delatometry-hmi.service
  delatometry-webui.service
)

if [ "$ENABLE_SERVICES" = "1" ]; then
  echo "[services] enabling services"
  sudo systemctl enable "${services[@]}"
fi

if [ "$START_SERVICES" = "1" ]; then
  echo "[services] starting services in dependency order"
  for svc in "${services[@]}"; do
    if [ "$svc" = "delatometry-ads1256.service" ]; then
      if grep -q '^DELATOMETRY_ADS1256_ENABLED="true"' "$ENV_FILE" 2>/dev/null; then
        sudo systemctl enable "$svc" 2>/dev/null || true
        sudo systemctl restart "$svc" || true
      else
        sudo systemctl disable "$svc" 2>/dev/null || true
        sudo systemctl stop "$svc" 2>/dev/null || true
        echo "[services] skipped $svc (DELATOMETRY_ADS1256_ENABLED=false)"
      fi
    else
      sudo systemctl restart "$svc" || true
    fi
    sleep 1
  done
fi

echo
echo "[services] installed:"
printf '  %s\n' "${services[@]}"
echo
echo "Status:"
echo "  $WORKSPACE/scripts/systemd/status.sh"
echo
echo "Logs:"
echo "  journalctl -u delatometry-webui.service -f"
