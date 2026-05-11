#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

require_bookworm

CURRENT_ROOT="$(repo_root_from_script)"
TARGET_DIR="${DLT_TARGET_DIR:-}"
MAIN_REPO="${DLT_MAIN_REPO:-$DEFAULT_MAIN_REPO}"
ENV_FILE="${DLT_ENV_FILE:-$DEFAULT_ENV_FILE}"

if [[ -z "$TARGET_DIR" ]]; then
  if [[ -n "$CURRENT_ROOT" && -d "$CURRENT_ROOT/src" ]]; then
    TARGET_DIR="$CURRENT_ROOT"
  else
    TARGET_DIR="$HOME/dlt"
  fi
fi

log "Workspace target: $TARGET_DIR"
mkdir -p "$TARGET_DIR"

if [[ -d "$TARGET_DIR/.git" || -f "$TARGET_DIR/.git" ]]; then
  log "Using existing workspace"
  git -C "$TARGET_DIR" remote get-url origin >/dev/null 2>&1 || git -C "$TARGET_DIR" remote add origin "$MAIN_REPO"
  git -C "$TARGET_DIR" fetch origin || true
  if git -C "$TARGET_DIR" ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
    git -C "$TARGET_DIR" checkout main || true
    git -C "$TARGET_DIR" pull --ff-only origin main || true
  else
    git -C "$TARGET_DIR" pull --ff-only || true
  fi
else
  log "Cloning main repository"
  git clone "$MAIN_REPO" "$TARGET_DIR"
fi

ensure_subrepos_updated "$TARGET_DIR"
ensure_env_file "$TARGET_DIR" "$ENV_FILE"
install_project_python_packages

log "Installing workspace dependencies via rosdep"
(
  cd "$TARGET_DIR"
  rosdep install --from-paths src --ignore-src -r -y --skip-keys='python3-mysql.connector' || \
    warn 'rosdep reported unresolved keys; continuing because Bookworm uses pip for mysql-connector-python'
)

log "Building workspace"
(
  cd "$TARGET_DIR"
  colcon build --symlink-install
)

install_service_units "$TARGET_DIR" "$USER" "$ENV_FILE"
enable_default_services
restart_default_services || warn 'One or more services failed to start; inspect with systemctl status'

log "Setup completed"
log "Workspace: $TARGET_DIR"
log "Environment file: $ENV_FILE"
log "Default services: dlt-database, dlt-core, dlt-ltm2985, dlt-webui"
