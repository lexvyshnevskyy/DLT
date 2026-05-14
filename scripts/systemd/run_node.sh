#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-/etc/default/delatometry}"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

NODE="${1:-}"
if [ -z "$NODE" ]; then
  echo "Usage: $0 <database|ltm2985_uart|measure_device|ads1256|core|hmi|webui>"
  exit 2
fi

: "${DELATOMETRY_WORKSPACE:=$HOME/ros2_delatometry}"
: "${DELATOMETRY_ROS_SETUP:=/opt/ros/jazzy/setup.bash}"
: "${DELATOMETRY_VENV:=$HOME/venvs/ros2_delatometry_webui}"

if [ ! -f "$DELATOMETRY_ROS_SETUP" ]; then
  echo "ERROR: ROS setup not found: $DELATOMETRY_ROS_SETUP"
  exit 10
fi

if [ ! -f "$DELATOMETRY_WORKSPACE/install/setup.bash" ]; then
  echo "ERROR: workspace setup not found: $DELATOMETRY_WORKSPACE/install/setup.bash"
  echo "Run: $DELATOMETRY_WORKSPACE/scripts/install.sh"
  exit 11
fi

# Source ROS safely even if parent used set -u.
set +u
# shellcheck disable=SC1090
source "$DELATOMETRY_ROS_SETUP"
if [ -d "$DELATOMETRY_VENV" ]; then
  # shellcheck disable=SC1090
  source "$DELATOMETRY_VENV/bin/activate"
fi
# shellcheck disable=SC1090
source "$DELATOMETRY_WORKSPACE/install/setup.bash"
set -u

cd "$DELATOMETRY_WORKSPACE"

case "$NODE" in
  database)
    : "${DELATOMETRY_DB_HOST:=127.0.0.1}"
    : "${DELATOMETRY_DB_PORT:=3306}"
    : "${DELATOMETRY_DB_NAME:=exp}"
    : "${DELATOMETRY_DB_USER:=delatometry}"
    : "${DELATOMETRY_DB_PASSWORD:=delatometry}"
    : "${DELATOMETRY_DB_AUTO_INIT_SCHEMA:=true}"

    args=(
      "db_host:=$DELATOMETRY_DB_HOST"
      "db_port:=$DELATOMETRY_DB_PORT"
      "db_name:=$DELATOMETRY_DB_NAME"
      "db_user:=$DELATOMETRY_DB_USER"
      "auto_init_schema:=$DELATOMETRY_DB_AUTO_INIT_SCHEMA"
    )
    # ROS 2 launch rejects an empty argument like db_password:=, so only pass
    # it when non-empty. db.launch.py default is empty.
    if [ -n "${DELATOMETRY_DB_PASSWORD:-}" ]; then
      args+=("db_password:=$DELATOMETRY_DB_PASSWORD")
    fi
    exec ros2 launch database db.launch.py "${args[@]}"
    ;;

  ltm2985_uart)
    : "${DELATOMETRY_LTM2985_PORT:=/dev/ttyUSB0}"
    : "${DELATOMETRY_LTM2985_BAUDRATE:=230400}"
    params="$DELATOMETRY_WORKSPACE/install/ltm2985_uart/share/ltm2985_uart/config/ltm2985_uart.params.yaml"
    exec ros2 run ltm2985_uart ltm2985_uart_node --ros-args \
      --params-file "$params" \
      -p "port:=$DELATOMETRY_LTM2985_PORT" \
      -p "baudrate:=$DELATOMETRY_LTM2985_BAUDRATE"
    ;;

  measure_device)
    : "${DELATOMETRY_MEASURE_PORT:=/dev/ttyUSB0}"
    : "${DELATOMETRY_MEASURE_SPEED:=9600}"
    exec ros2 launch measure_device measure_device.launch.py \
      "port:=$DELATOMETRY_MEASURE_PORT" \
      "speed:=$DELATOMETRY_MEASURE_SPEED"
    ;;

  ads1256)
    : "${DELATOMETRY_ADS1256_SIMULATE:=false}"
    : "${DELATOMETRY_ADS1256_FALLBACK_TO_SIMULATION:=true}"
    exec ros2 launch ads1256 ads1256.launch.py \
      "simulate:=$DELATOMETRY_ADS1256_SIMULATE" \
      "fallback_to_simulation:=$DELATOMETRY_ADS1256_FALLBACK_TO_SIMULATION"
    ;;

  core)
    : "${DELATOMETRY_CORE_NAMESPACE:=core}"
    : "${DELATOMETRY_CORE_MEASUREMENT_TOPIC:=/ltm2985/measurement}"
    : "${DELATOMETRY_CORE_ENABLE_DATABASE_CLIENT:=false}"
    : "${DELATOMETRY_CORE_ENABLE_PWM_CONTROLLER:=false}"
    params="$DELATOMETRY_WORKSPACE/install/core/share/core/config/core.params.yaml"
    exec ros2 run core run.py --ros-args \
      -r "__ns:=/$DELATOMETRY_CORE_NAMESPACE" \
      --params-file "$params" \
      -p "measurement_topic:=$DELATOMETRY_CORE_MEASUREMENT_TOPIC" \
      -p "enable_database_client:=$DELATOMETRY_CORE_ENABLE_DATABASE_CLIENT" \
      -p "enable_pwm_controller:=$DELATOMETRY_CORE_ENABLE_PWM_CONTROLLER"
    ;;

  hmi)
    : "${DELATOMETRY_HMI_PORT:=/dev/ttyS0}"
    : "${DELATOMETRY_HMI_BAUDRATE:=115200}"
    : "${DELATOMETRY_HMI_DATABASE_REQUIRED:=true}"
    : "${DELATOMETRY_HMI_DATABASE_WAIT_TIMEOUT_SEC:=30.0}"
    exec ros2 launch hmi hmi.launch.py \
      "port:=$DELATOMETRY_HMI_PORT" \
      "baudrate:=$DELATOMETRY_HMI_BAUDRATE" \
      "database_required:=$DELATOMETRY_HMI_DATABASE_REQUIRED" \
      "database_wait_timeout_sec:=$DELATOMETRY_HMI_DATABASE_WAIT_TIMEOUT_SEC"
    ;;

  webui)
    exec ros2 launch webui webui.launch.py
    ;;

  *)
    echo "ERROR: unknown node '$NODE'"
    exit 2
    ;;
esac
