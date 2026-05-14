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
  sudo systemctl stop "$svc" || true
done
