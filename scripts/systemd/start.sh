#!/usr/bin/env bash
set -euo pipefail

services=(
  delatometry-database.service
  delatometry-ltm2985.service
  delatometry-measure-device.service
  delatometry-ads1256.service
  delatometry-core.service
  delatometry-hmi.service
  delatometry-webui.service
)

for svc in "${services[@]}"; do
  sudo systemctl restart "$svc"
  sleep 1
done

systemctl --no-pager --full status "${services[@]}"
