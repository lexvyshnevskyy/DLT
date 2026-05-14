#!/usr/bin/env bash
set -euo pipefail

services=(
  delatometry-webui.service
  delatometry-hmi.service
  delatometry-core.service
  delatometry-ads1256.service
  delatometry-measure-device.service
  delatometry-ltm2985.service
  delatometry-database.service
)

for svc in "${services[@]}"; do
  sudo systemctl disable --now "$svc" || true
  sudo rm -f "/etc/systemd/system/$svc"
done

sudo systemctl daemon-reload

echo "Removed Delatometry systemd services."
echo "Kept /etc/default/delatometry for reference."
