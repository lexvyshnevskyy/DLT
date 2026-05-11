#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="delatometry"
DEFAULT_MAIN_REPO="git@github.com:lexvyshnevskyy/DLT.git"
DEFAULT_ENV_FILE="/etc/delatometry/delatometry.env"

log() { printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"; }
warn() { printf '\n[WARN] %s\n' "$*" >&2; }
die() { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

script_dir() {
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
}

repo_root_from_script() {
  local sdir
  sdir="$(script_dir)"
  git -C "$sdir/.." rev-parse --show-toplevel 2>/dev/null || true
}

require_bookworm() {
  if [[ ! -r /etc/os-release ]]; then
    die "/etc/os-release is missing"
  fi
  # shellcheck disable=SC1091
  source /etc/os-release
  local codename="${VERSION_CODENAME:-${DEBIAN_CODENAME:-}}"
  if [[ "${ID:-}" != "debian" && "${ID:-}" != "raspbian" ]]; then
    die "This installer is intended for Debian/Raspberry Pi OS Bookworm. Detected ID=${ID:-unknown}"
  fi
  if [[ "$codename" != "bookworm" ]]; then
    die "This installer is intended for Bookworm. Detected codename=${codename:-unknown}"
  fi
}

apt_install() {
  sudo apt-get install -y --no-install-recommends "$@"
}

apt_install_if_available() {
  local pkg
  local available=()
  for pkg in "$@"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    fi
  done
  if [[ ${#available[@]} -gt 0 ]]; then
    sudo apt-get install -y --no-install-recommends "${available[@]}"
  fi
}

ensure_system_groups() {
  local user_name="$1"
  sudo usermod -aG dialout "$user_name" || true
  if getent group gpio >/dev/null 2>&1; then
    sudo usermod -aG gpio "$user_name" || true
  fi
}

ensure_env_file() {
  local workspace="$1"
  local env_file="${2:-$DEFAULT_ENV_FILE}"
  sudo mkdir -p "$(dirname "$env_file")"
  if [[ ! -f "$env_file" ]]; then
    log "Creating $env_file"
    sudo tee "$env_file" >/dev/null <<EOF_ENV
DLT_WORKSPACE=$workspace
DLT_DB_HOST=127.0.0.1
DLT_DB_PORT=3306
DLT_DB_NAME=exp
DLT_DB_USER=dlt
DLT_DB_PASSWORD=dlt
DLT_LTM_PORT=/dev/ttyUSB0
DLT_LTM_BAUDRATE=230400
DLT_HMI_PORT=/dev/ttyS0
DLT_HMI_BAUDRATE=115200
DLT_E720_PORT=/dev/ttyUSB1
DLT_E720_BAUDRATE=9600
DLT_WEBUI_HOST=0.0.0.0
DLT_WEBUI_PORT=7860
EOF_ENV
    sudo chmod 600 "$env_file"
  else
    log "Keeping existing $env_file"
    if ! sudo grep -q '^DLT_WORKSPACE=' "$env_file"; then
      echo "DLT_WORKSPACE=$workspace" | sudo tee -a "$env_file" >/dev/null
    else
      sudo sed -i "s#^DLT_WORKSPACE=.*#DLT_WORKSPACE=$workspace#" "$env_file"
    fi
  fi
}

rosdep_init_if_needed() {
  if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
    log "Initializing rosdep"
    sudo rosdep init
  fi
  rosdep update
}

ensure_pigpio() {
  log "Installing pigpio support"
  sudo apt-get update
  if apt-cache show pigpio >/dev/null 2>&1; then
    apt_install pigpio python3-pigpio pigpio-tools
  else
    apt_install python3-pigpio pigpio-tools wget unzip make gcc
    local tmpdir
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' RETURN
    (
      cd "$tmpdir"
      wget -q https://github.com/joan2937/pigpio/archive/master.zip -O pigpio-master.zip
      unzip -q pigpio-master.zip
      cd pigpio-master
      make
      sudo make install
    )
  fi

  if ! systemctl list-unit-files | grep -q '^pigpiod\.service'; then
    log "Creating pigpiod.service"
    sudo tee /etc/systemd/system/pigpiod.service >/dev/null <<'EOF_PIG'
[Unit]
Description=pigpio daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/pigpiod
PIDFile=/run/pigpio.pid
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF_PIG
    sudo systemctl daemon-reload
  fi

  sudo systemctl enable pigpiod.service
  sudo systemctl restart pigpiod.service || true
}

setup_database_from_env() {
  local env_file="${1:-$DEFAULT_ENV_FILE}"
  [[ -f "$env_file" ]] || die "Environment file not found: $env_file"
  # shellcheck disable=SC1090
  source "$env_file"
  sudo systemctl enable mariadb.service mysql.service >/dev/null 2>&1 || true
  sudo systemctl restart mariadb.service >/dev/null 2>&1 || sudo systemctl restart mysql.service >/dev/null 2>&1 || true
  log "Configuring database \${DLT_DB_NAME} and user \${DLT_DB_USER}"
  sudo mysql <<EOF_SQL
CREATE DATABASE IF NOT EXISTS \`\${DLT_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '\${DLT_DB_USER}'@'localhost' IDENTIFIED BY '\${DLT_DB_PASSWORD}';
CREATE USER IF NOT EXISTS '\${DLT_DB_USER}'@'127.0.0.1' IDENTIFIED BY '\${DLT_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`\${DLT_DB_NAME}\`.* TO '\${DLT_DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`\${DLT_DB_NAME}\`.* TO '\${DLT_DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF_SQL
}

start_ssh_agent_and_add() {
  if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
    eval "$(ssh-agent -s)"
  fi
  if ! ssh-add -l >/dev/null 2>&1; then
    ssh-add || warn "ssh-add did not load a key; continuing"
  fi
}

known_repo_url_for_path() {
  case "$1" in
    src/hmi) echo 'git@github.com:lexvyshnevskyy/DLT_hmi.git' ;;
    src/database) echo 'git@github.com:lexvyshnevskyy/DLT_database.git' ;;
    src/measure_device) echo 'git@github.com:lexvyshnevskyy/DLT_measure_device.git' ;;
    src/core) echo 'git@github.com:lexvyshnevskyy/DLT_core.git' ;;
    src/ltm2985_uart) echo 'git@github.com:lexvyshnevskyy/DLT_ltm2985.git' ;;
    src/webui) echo 'git@github.com:lexvyshnevskyy/DLT_webui.git' ;;
    src/ads1256) echo 'git@github.com:lexvyshnevskyy/DLT_ads1256.git' ;;
    *) return 1 ;;
  esac
}

ensure_subrepos_updated() {
  local workspace="$1"
  log "Updating nested repositories/submodules"
  if [[ -f "$workspace/.gitmodules" ]]; then
    git -C "$workspace" submodule sync --recursive || true
    git -C "$workspace" submodule update --init --recursive || warn "git submodule update returned non-zero, applying manual repo fallback"
  fi

  local path url
  for path in src/hmi src/database src/measure_device src/core src/ltm2985_uart src/webui src/ads1256; do
    url="$(known_repo_url_for_path "$path" || true)"
    if [[ -z "$url" ]]; then
      continue
    fi
    if [[ -d "$workspace/$path/.git" || -f "$workspace/$path/.git" ]]; then
      git -C "$workspace/$path" fetch origin || true
      if git -C "$workspace/$path" ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
        git -C "$workspace/$path" checkout main || true
        git -C "$workspace/$path" pull --ff-only origin main || true
      else
        git -C "$workspace/$path" pull --ff-only || true
      fi
    elif [[ ! -e "$workspace/$path" ]]; then
      mkdir -p "$(dirname "$workspace/$path")"
      git clone "$url" "$workspace/$path"
    fi
  done
}

install_project_python_packages() {
  log "Installing Python packages"
  python3 -m pip install --upgrade pip setuptools wheel --break-system-packages
  python3 -m pip install --break-system-packages \
    pyserial \
    psutil \
    numpy \
    mysql-connector-python \
    gradio \
    pipyadc
}

install_system_service() {
  local service_name="$1"
  local contents="$2"
  local target="/etc/systemd/system/${service_name}"
  printf '%s\n' "$contents" | sudo tee "$target" >/dev/null
}

install_service_units() {
  local workspace="$1"
  local service_user="$2"
  local env_file="${3:-$DEFAULT_ENV_FILE}"

  sudo mkdir -p /etc/delatometry
  ensure_env_file "$workspace" "$env_file"

  local db_service core_service ltm_service web_service hmi_service measure_service ads_service

  db_service="[Unit]
Description=Delatometry database node
After=network-online.target mariadb.service mysql.service
Wants=network-online.target

[Service]
Type=simple
User=${service_user}
SupplementaryGroups=dialout gpio
WorkingDirectory=${workspace}
EnvironmentFile=-${env_file}
ExecStart=/bin/bash -lc 'source "${workspace}/install/setup.bash" && exec "${workspace}/install/database/lib/database/run.py" --ros-args -p publish_rate:=100.0 -p response_endpoint:=response -p query_endpoint:=query -p db.host:="\${DLT_DB_HOST}" -p db.port:=\${DLT_DB_PORT} -p db.user:="\${DLT_DB_USER}" -p db.password:="\${DLT_DB_PASSWORD}" -p db.name:="\${DLT_DB_NAME}" -p auto_init_schema:=true'
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target"

  core_service="[Unit]
Description=Delatometry core node
After=network-online.target pigpiod.service dlt-database.service
Wants=network-online.target
Requires=dlt-database.service

[Service]
Type=simple
User=${service_user}
SupplementaryGroups=dialout gpio
WorkingDirectory=${workspace}
EnvironmentFile=-${env_file}
ExecStart=/bin/bash -lc 'source "${workspace}/install/setup.bash" && exec "${workspace}/install/core/lib/core/run.py" --ros-args --params-file "${workspace}/install/core/share/core/config/core.params.yaml"'
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target"

  ltm_service="[Unit]
Description=Delatometry LTM2985 UART node
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${service_user}
SupplementaryGroups=dialout gpio
WorkingDirectory=${workspace}
EnvironmentFile=-${env_file}
ExecStart=/bin/bash -lc 'source "${workspace}/install/setup.bash" && exec "${workspace}/install/ltm2985_uart/lib/ltm2985_uart/ltm2985_uart_node" --ros-args --params-file "${workspace}/install/ltm2985_uart/share/ltm2985_uart/config/ltm2985_uart.params.yaml" -p port:="\${DLT_LTM_PORT}" -p baudrate:=\${DLT_LTM_BAUDRATE}'
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target"

  web_service="[Unit]
Description=Delatometry web UI node
After=network-online.target dlt-database.service dlt-core.service dlt-ltm2985.service
Wants=network-online.target
Requires=dlt-database.service dlt-core.service

[Service]
Type=simple
User=${service_user}
SupplementaryGroups=dialout gpio
WorkingDirectory=${workspace}
EnvironmentFile=-${env_file}
ExecStart=/bin/bash -lc 'source "${workspace}/install/setup.bash" && exec "${workspace}/install/webui/lib/webui/run.py" --ros-args --params-file "${workspace}/install/webui/share/webui/config/web_hmi.params.yaml" -p bind_host:="\${DLT_WEBUI_HOST}" -p bind_port:=\${DLT_WEBUI_PORT}'
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target"

  hmi_service="[Unit]
Description=Delatometry HMI serial bridge
After=network-online.target dlt-database.service
Wants=network-online.target

[Service]
Type=simple
User=${service_user}
SupplementaryGroups=dialout gpio
WorkingDirectory=${workspace}
EnvironmentFile=-${env_file}
ExecStart=/bin/bash -lc 'source "${workspace}/install/setup.bash" && exec "${workspace}/install/hmi/lib/hmi/run" --ros-args -p endpoint:=hmi -p publish_rate:=4.0 -p port:="\${DLT_HMI_PORT}" -p baudrate:=\${DLT_HMI_BAUDRATE} -p ads_topic:=/ads1256 -p measure_topic:=/measure_device -p database_service:=/database/query'
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target"

  measure_service="[Unit]
Description=Delatometry E7-20 measure device node
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${service_user}
SupplementaryGroups=dialout gpio
WorkingDirectory=${workspace}
EnvironmentFile=-${env_file}
ExecStart=/bin/bash -lc 'source "${workspace}/install/setup.bash" && exec "${workspace}/install/measure_device/lib/measure_device/measure_device_node" --ros-args --params-file "${workspace}/install/measure_device/share/measure_device/config/measure_device.params.yaml" -p port:="\${DLT_E720_PORT}" -p speed:=\${DLT_E720_BAUDRATE}'
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target"

  ads_service="[Unit]
Description=Delatometry ADS1256 node
After=network-online.target pigpiod.service
Wants=network-online.target

[Service]
Type=simple
User=${service_user}
SupplementaryGroups=dialout gpio
WorkingDirectory=${workspace}
EnvironmentFile=-${env_file}
ExecStart=/bin/bash -lc 'source "${workspace}/install/setup.bash" && exec "${workspace}/install/ads1256/lib/ads1256/ads1256_node" --ros-args --params-file "${workspace}/install/ads1256/share/ads1256/config/ads1256.params.yaml"'
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target"

  install_system_service dlt-database.service "$db_service"
  install_system_service dlt-core.service "$core_service"
  install_system_service dlt-ltm2985.service "$ltm_service"
  install_system_service dlt-webui.service "$web_service"
  install_system_service dlt-hmi.service "$hmi_service"
  install_system_service dlt-measure-device.service "$measure_service"
  install_system_service dlt-ads1256.service "$ads_service"

  sudo systemctl daemon-reload
}

enable_default_services() {
  sudo systemctl enable dlt-database.service dlt-core.service dlt-ltm2985.service dlt-webui.service
}

restart_default_services() {
  sudo systemctl restart dlt-database.service dlt-core.service dlt-ltm2985.service dlt-webui.service
}
