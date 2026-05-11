#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_not_root
ROS_DISTRO="$(resolve_ros_distro)"
WORKSPACE="$(workspace_root)"

log "Workspace: ${WORKSPACE}"
log "ROS distro: ${ROS_DISTRO}"

ensure_ssh_agent
update_nested_git_repos "${WORKSPACE}"
source_ros "${ROS_DISTRO}"
install_python_requirements "${WORKSPACE}"
build_workspace "${WORKSPACE}" "${ROS_DISTRO}"
write_env_file "${WORKSPACE}" "${ROS_DISTRO}" "${USER}"
install_service_units "${WORKSPACE}" "${USER}"
sudo systemctl daemon-reload
restart_services_from_env

log "Update, rebuild, and service restart finished."
