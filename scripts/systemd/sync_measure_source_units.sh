#!/usr/bin/env bash
# Enable the configured meter service for boot and disable the other.
# Runs before core/webui so restarts keep IM3536 (or E7-20) without reconfiguration.
set -euo pipefail

ENV_FILE="${ENV_FILE:-/etc/default/delatometry}"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

: "${DELATOMETRY_MEASURE_SOURCE:=e720}"
SOURCE="$(echo "$DELATOMETRY_MEASURE_SOURCE" | tr '[:upper:]' '[:lower:]')"

if [ "$SOURCE" = "im3536" ]; then
  ACTIVE="delatometry-im3536.service"
  INACTIVE="delatometry-measure-device.service"
else
  ACTIVE="delatometry-measure-device.service"
  INACTIVE="delatometry-im3536.service"
fi

systemctl disable --now "$INACTIVE" 2>/dev/null || true
systemctl enable "$ACTIVE" 2>/dev/null || true
# Start only if not already active. Use --no-block so this oneshot does not
# deadlock when ACTIVE has After=delatometry-measure-source.service.
if ! systemctl is-active --quiet "$ACTIVE"; then
  systemctl --no-block start "$ACTIVE" 2>/dev/null || true
fi

echo "[measure-source] active=$ACTIVE inactive=$INACTIVE source=$SOURCE"
