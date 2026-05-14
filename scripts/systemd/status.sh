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

systemctl --no-pager --full status "${services[@]}"
