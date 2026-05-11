#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

require_bookworm

WORKSPACE="${DLT_TARGET_DIR:-$(repo_root_from_script)}"
ENV_FILE="${DLT_ENV_FILE:-$DEFAULT_ENV_FILE}"
[[ -n "$WORKSPACE" ]] || die "Unable to determine workspace path"
[[ -d "$WORKSPACE/.git" || -f "$WORKSPACE/.git" ]] || die "Workspace is not a git repository: $WORKSPACE"

start_ssh_agent_and_add

log "Pulling latest main repository changes"
if git -C "$WORKSPACE" ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
  git -C "$WORKSPACE" checkout main || true
  git -C "$WORKSPACE" pull --ff-only origin main
else
  git -C "$WORKSPACE" pull --ff-only
fi

ensure_subrepos_updated "$WORKSPACE"
install_project_python_packages

log "Refreshing dependencies via rosdep"
(
  cd "$WORKSPACE"
  rosdep install --from-paths src --ignore-src -r -y --skip-keys='python3-mysql.connector' || \
    warn 'rosdep reported unresolved keys; continuing'
)

log "Rebuilding workspace"
(
  cd "$WORKSPACE"
  colcon build --symlink-install
)

install_service_units "$WORKSPACE" "$USER" "$ENV_FILE"
enable_default_services
restart_default_services

log "Update/build/restart cycle finished"
