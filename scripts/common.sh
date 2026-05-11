#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_REMOTE_REPO="git@github.com:lexvyshnevskyy/DLT.git"
DEFAULT_WORKSPACE="${HOME}/dlt"
ENV_DIR="/etc/delatometry"
ENV_FILE="${ENV_DIR}/delatometry.env"

log() { echo "[DLT] $*"; }
warn() { echo "[DLT][WARN] $*" >&2; }
die() { echo "[DLT][ERROR] $*" >&2; exit 1; }

require_not_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    die "Run this script as your regular user, not as root. It will call sudo when needed."
  fi
}

workspace_root() {
  if git -C "${REPO_ROOT}" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "${REPO_ROOT}" rev-parse --show-toplevel
  else
    printf '%s\n' "${DEFAULT_WORKSPACE}"
  fi
}

current_remote_repo() {
  local ws
  ws="$(workspace_root)"
  if git -C "${ws}" remote get-url origin >/dev/null 2>&1; then
    git -C "${ws}" remote get-url origin
  else
    printf '%s\n' "${DEFAULT_REMOTE_REPO}"
  fi
}

ensure_locale() {
  sudo apt-get update
  sudo apt-get install -y locales
  sudo locale-gen en_US en_US.UTF-8
  sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
  export LANG=en_US.UTF-8
}

ensure_ros_repo_and_tools() {
  local ros_distro="$1"
  sudo apt-get install -y software-properties-common curl gnupg2 ca-certificates lsb-release
  sudo add-apt-repository -y universe || true
  sudo apt-get update && sudo apt-get install -y curl
  local ros_apt_source_version
  ros_apt_source_version="$(curl -fsSL https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F 'tag_name' | awk -F'"' '{print $4}')"
  [[ -n "${ros_apt_source_version}" ]] || die "Failed to query ros-apt-source release version."
  local codename
  codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME}}")"
  curl -fL -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ros_apt_source_version}/ros2-apt-source_${ros_apt_source_version}.${codename}_all.deb"
  sudo dpkg -i /tmp/ros2-apt-source.deb
  sudo apt-get update
  sudo apt-get -y upgrade
  sudo apt-get install -y "ros-${ros_distro}-ros-base" ros-dev-tools
}

resolve_ros_distro() {
  if [[ -n "${ROS_DISTRO:-}" ]]; then
    printf '%s\n' "${ROS_DISTRO}"
    return
  fi

  local id version_id
  id="$(. /etc/os-release && echo "${ID}")"
  version_id="$(. /etc/os-release && echo "${VERSION_ID}")"

  if [[ "${id}" == "ubuntu" && "${version_id}" == "24.04" ]]; then
    printf 'jazzy\n'
    return
  fi
  if [[ "${id}" == "ubuntu" && "${version_id}" == "22.04" ]]; then
    printf 'humble\n'
    return
  fi

  if compgen -G "/opt/ros/*/setup.bash" >/dev/null 2>&1; then
    basename "$(dirname "$(ls -d /opt/ros/* | head -n1)")" >/dev/null 2>&1 || true
    basename "$(ls -d /opt/ros/* | head -n1)"
    return
  fi

  die "Unsupported OS for automatic ROS install. Supported here: Ubuntu 24.04 -> Jazzy, Ubuntu 22.04 -> Humble. On other systems install ROS manually first and set ROS_DISTRO before running setup scripts."
}

source_ros() {
  local ros_distro="$1"
  local setup_file="/opt/ros/${ros_distro}/setup.bash"
  [[ -f "${setup_file}" ]] || die "ROS setup not found: ${setup_file}"
  # shellcheck disable=SC1090
  source "${setup_file}"
}

ensure_rosdep_initialized() {
  if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
    sudo rosdep init
  fi
  rosdep update
}

ensure_ssh_agent() {
  if ssh-add -l >/dev/null 2>&1; then
    return
  fi
  eval "$(ssh-agent -s)" >/dev/null
  local key_added=0
  for key in "${HOME}/.ssh/id_ed25519" "${HOME}/.ssh/id_rsa"; do
    if [[ -f "${key}" ]]; then
      ssh-add "${key}"
      key_added=1
      break
    fi
  done
  if [[ "${key_added}" -eq 0 ]]; then
    warn "No default SSH private key found. Git operations may still fail if your repo needs SSH auth."
  fi
}

clone_or_update_workspace() {
  local ws="$1"
  local remote_repo="$2"
  mkdir -p "${ws}"
  if [[ ! -d "${ws}/.git" ]]; then
    log "Cloning ${remote_repo} into ${ws}"
    git clone "${remote_repo}" "${ws}"
  else
    log "Updating main repository in ${ws}"
    git -C "${ws}" pull --ff-only || warn "Main repo pull failed; leaving current checkout in place."
  fi
}

update_nested_git_repos() {
  local ws="$1"
  log "Syncing registered submodules if available"
  git -C "${ws}" submodule sync --recursive || true
  git -C "${ws}" submodule update --init --recursive || true

  log "Updating nested git repositories"
  while IFS= read -r git_dir; do
    local repo_dir branch
    repo_dir="$(dirname "${git_dir}")"
    if [[ "${repo_dir}" == "${ws}/.git" ]]; then
      repo_dir="${ws}"
    fi
    if ! git -C "${repo_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      continue
    fi
    log "→ ${repo_dir}"
    git -C "${repo_dir}" fetch --all --prune || true
    branch="$(git -C "${repo_dir}" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [[ -z "${branch}" ]]; then
      if git -C "${repo_dir}" ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
        git -C "${repo_dir}" checkout main || true
        branch="main"
      fi
    fi
    if [[ -n "${branch}" ]]; then
      git -C "${repo_dir}" pull --ff-only origin "${branch}" || true
    fi
  done < <(find "${ws}" -type d -name .git | sort)
}

install_python_requirements() {
  local ws="$1"
  python3 -m pip install --user --upgrade pip wheel setuptools
  if find "${ws}/src" -name requirements.txt -print -quit >/dev/null 2>&1; then
    while IFS= read -r req; do
      log "Installing Python requirements from ${req}"
      python3 -m pip install --user -r "${req}"
    done < <(find "${ws}/src" -name requirements.txt | sort)
  fi
  python3 -m pip install --user pyserial psutil gradio mysql-connector-python
}

run_rosdep_install() {
  local ws="$1"
  local ros_distro="$2"
  (cd "${ws}" && rosdep install --from-paths src --ignore-src -r -y --rosdistro "${ros_distro}")
}

build_workspace() {
  local ws="$1"
  local ros_distro="$2"
  source_ros "${ros_distro}"
  (cd "${ws}" && colcon build --symlink-install --event-handlers console_direct+)
}

write_env_file() {
  local ws="$1"
  local ros_distro="$2"
  local user_name="$3"
  sudo mkdir -p "${ENV_DIR}"
  if [[ ! -f "${ENV_FILE}" ]]; then
    log "Creating ${ENV_FILE}"
    sudo tee "${ENV_FILE}" >/dev/null <<EOF_ENV
ROS_DISTRO=${ros_distro}
DLT_USER=${user_name}
DLT_WORKSPACE=${ws}
DLT_DB_HOST=127.0.0.1
DLT_DB_PORT=3306
DLT_DB_NAME=exp
DLT_DB_USER=dlt
DLT_DB_PASSWORD=dlt
DLT_CORE_PARAMS=${ws}/install/core/share/core/config/core.params.yaml
DLT_LTM2985_PARAMS=${ws}/install/ltm2985_uart/share/ltm2985_uart/config/ltm2985_uart.params.yaml
DLT_WEBUI_PARAMS=${ws}/install/webui/share/webui/config/web_hmi.params.yaml
DLT_ENABLE_DATABASE=1
DLT_ENABLE_CORE=1
DLT_ENABLE_LTM2985=1
DLT_ENABLE_WEBUI=1
DLT_ENABLE_MEASURE_DEVICE=0
DLT_ENABLE_HMI=0
DLT_ENABLE_ADS1256=0
EOF_ENV
    sudo chmod 600 "${ENV_FILE}"
  else
    log "Keeping existing ${ENV_FILE}"
  fi
}

configure_mysql() {
  log "Configuring MySQL database and user"
  sudo systemctl enable --now mysql
  local db_name db_user db_password
  db_name="$(sudo awk -F= '/^DLT_DB_NAME=/{print $2}' "${ENV_FILE}" | tail -n1)"
  db_user="$(sudo awk -F= '/^DLT_DB_USER=/{print $2}' "${ENV_FILE}" | tail -n1)"
  db_password="$(sudo awk -F= '/^DLT_DB_PASSWORD=/{print $2}' "${ENV_FILE}" | tail -n1)"
  sudo mysql <<EOF_SQL
CREATE DATABASE IF NOT EXISTS \
  \
\`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '${db_password}';
CREATE USER IF NOT EXISTS '${db_user}'@'127.0.0.1' IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'localhost';
GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF_SQL
}

write_service_file() {
  local service_name="$1"
  local unit_content="$2"
  sudo tee "/etc/systemd/system/${service_name}" >/dev/null <<<"${unit_content}"
}

install_service_units() {
  local ws="$1"
  local user_name="$2"

  write_service_file "dlt-database.service" "[Unit]
Description=Delatometry database ROS 2 node
After=network-online.target mysql.service
Wants=network-online.target
Requires=mysql.service

[Service]
Type=simple
User=${user_name}
WorkingDirectory=${ws}
EnvironmentFile=-${ENV_FILE}
ExecStart=/bin/bash -lc 'source /opt/ros/${ROS_DISTRO}/setup.bash && source ${ws}/install/setup.bash && exec ros2 launch database db.launch.py db_host:=\${DLT_DB_HOST} db_port:=\${DLT_DB_PORT} db_user:=\${DLT_DB_USER} db_password:=\${DLT_DB_PASSWORD} db_name:=\${DLT_DB_NAME} auto_init_schema:=true'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
"

  write_service_file "dlt-core.service" "[Unit]
Description=Delatometry core ROS 2 node
After=network-online.target pigpiod.service dlt-database.service
Wants=network-online.target pigpiod.service
Requires=dlt-database.service

[Service]
Type=simple
User=${user_name}
WorkingDirectory=${ws}
EnvironmentFile=-${ENV_FILE}
ExecStart=/bin/bash -lc 'source /opt/ros/${ROS_DISTRO}/setup.bash && source ${ws}/install/setup.bash && exec ros2 launch core core.launch.py params_file:=\${DLT_CORE_PARAMS}'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
"

  write_service_file "dlt-ltm2985.service" "[Unit]
Description=Delatometry LTM2985 UART ROS 2 node
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${user_name}
WorkingDirectory=${ws}
EnvironmentFile=-${ENV_FILE}
ExecStart=/bin/bash -lc 'source /opt/ros/${ROS_DISTRO}/setup.bash && source ${ws}/install/setup.bash && exec ros2 launch ltm2985_uart ltm2985_uart.launch.py params_file:=\${DLT_LTM2985_PARAMS}'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
"

  write_service_file "dlt-webui.service" "[Unit]
Description=Delatometry web UI ROS 2 node
After=network-online.target dlt-database.service dlt-core.service dlt-ltm2985.service
Wants=network-online.target
Requires=dlt-database.service dlt-core.service

[Service]
Type=simple
User=${user_name}
WorkingDirectory=${ws}
EnvironmentFile=-${ENV_FILE}
ExecStart=/bin/bash -lc 'source /opt/ros/${ROS_DISTRO}/setup.bash && source ${ws}/install/setup.bash && exec ros2 run webui run.py --ros-args --params-file \${DLT_WEBUI_PARAMS}'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
"

  write_service_file "dlt-measure-device.service" "[Unit]
Description=Delatometry E7-20 measure device ROS 2 node
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${user_name}
WorkingDirectory=${ws}
EnvironmentFile=-${ENV_FILE}
ExecStart=/bin/bash -lc 'source /opt/ros/${ROS_DISTRO}/setup.bash && source ${ws}/install/setup.bash && exec ros2 launch measure_device measure_device.launch.py'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
"

  write_service_file "dlt-hmi.service" "[Unit]
Description=Delatometry HMI RS232 ROS 2 node
After=network-online.target dlt-database.service
Wants=network-online.target
Requires=dlt-database.service

[Service]
Type=simple
User=${user_name}
WorkingDirectory=${ws}
EnvironmentFile=-${ENV_FILE}
ExecStart=/bin/bash -lc 'source /opt/ros/${ROS_DISTRO}/setup.bash && source ${ws}/install/setup.bash && exec ros2 launch hmi hmi.launch.py'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
"

  write_service_file "dlt-ads1256.service" "[Unit]
Description=Delatometry ADS1256 ROS 2 node
After=network-online.target pigpiod.service
Wants=network-online.target pigpiod.service

[Service]
Type=simple
User=${user_name}
WorkingDirectory=${ws}
EnvironmentFile=-${ENV_FILE}
ExecStart=/bin/bash -lc 'source /opt/ros/${ROS_DISTRO}/setup.bash && source ${ws}/install/setup.bash && exec ros2 launch ads1256 ads1256.launch.py'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
"

  sudo systemctl daemon-reload
}

enable_services_from_env() {
  mapfile -t services < <(sudo awk -F= '
    /^DLT_ENABLE_DATABASE=1$/ {print "dlt-database.service"}
    /^DLT_ENABLE_CORE=1$/ {print "dlt-core.service"}
    /^DLT_ENABLE_LTM2985=1$/ {print "dlt-ltm2985.service"}
    /^DLT_ENABLE_WEBUI=1$/ {print "dlt-webui.service"}
    /^DLT_ENABLE_MEASURE_DEVICE=1$/ {print "dlt-measure-device.service"}
    /^DLT_ENABLE_HMI=1$/ {print "dlt-hmi.service"}
    /^DLT_ENABLE_ADS1256=1$/ {print "dlt-ads1256.service"}
  ' "${ENV_FILE}")
  if [[ "${#services[@]}" -gt 0 ]]; then
    sudo systemctl enable "${services[@]}"
  fi
}

restart_services_from_env() {
  mapfile -t services < <(sudo awk -F= '
    /^DLT_ENABLE_DATABASE=1$/ {print "dlt-database.service"}
    /^DLT_ENABLE_CORE=1$/ {print "dlt-core.service"}
    /^DLT_ENABLE_LTM2985=1$/ {print "dlt-ltm2985.service"}
    /^DLT_ENABLE_WEBUI=1$/ {print "dlt-webui.service"}
    /^DLT_ENABLE_MEASURE_DEVICE=1$/ {print "dlt-measure-device.service"}
    /^DLT_ENABLE_HMI=1$/ {print "dlt-hmi.service"}
    /^DLT_ENABLE_ADS1256=1$/ {print "dlt-ads1256.service"}
  ' "${ENV_FILE}")
  if [[ "${#services[@]}" -gt 0 ]]; then
    sudo systemctl restart "${services[@]}"
  fi
}
