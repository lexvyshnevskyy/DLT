#!/usr/bin/env bash
set -euo pipefail

svc="${1:-all}"

if [ "$svc" = "all" ]; then
  journalctl -u delatometry-database.service \
             -u delatometry-ltm2985.service \
             -u delatometry-measure-device.service \
             -u delatometry-ads1256.service \
             -u delatometry-core.service \
             -u delatometry-hmi.service \
             -u delatometry-webui.service \
             -f
else
  journalctl -u "delatometry-${svc}.service" -f
fi
