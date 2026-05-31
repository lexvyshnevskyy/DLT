# Delatometry ROS 2 — Overview

Delatometry is a **ROS 2 Jazzy** workspace for running temperature-programmed experiments on a Raspberry Pi (or similar Linux host). It drives an LTM2985 heater channel, logs synchronized measurements, stores results in **MariaDB**, and exposes a **browser HMI** plus an optional **Nextion serial display**.

## What the system does

1. **Programs** — Multi-step temperature ramps (40–1600 K) with optional E7-20 frequency sweeps.
2. **Core control** — PI heating, program scheduler, and measurement logging run in the `core` node (not in the web UI).
3. **Persistence** — Programs, steps, runs, and time-series samples live in MariaDB via the `database` node.
4. **Operator interfaces** — FastAPI web UI (port 80 by default) and `hmi` for RS-232 Nextion panels.

## Design principle

> **Core owns experiments.** Web UI and HMI only start, stop, configure, and display. If the browser restarts, a running program continues on the device.

## Repository layout

| Path | Role |
|------|------|
| `src/core` | Experiment scheduler, PI/PWM, `/core/query`, status publisher |
| `src/webui` | FastAPI + ROS bridge to DB and core |
| `src/database` | MariaDB access, `/database/query` service |
| `src/hmi` | Nextion display over UART |
| `src/ltm2985_uart` | LTM2985 temperature / control channel |
| `src/measure_device` | External measurement hardware |
| `src/ads1256` | Optional ADC node |
| `src/msgs` | Custom messages and services |
| `scripts/install.sh` | Full install and rebuild |
| `scripts/systemd/` | Service units and helpers |
| `docs/en`, `docs/uk` | This documentation (also in Web UI **Documentation**) |

## Quick start

```bash
cd ~/ros2_delatometry
bash scripts/install.sh
# Choose full install or rebuild; then open http://<device-ip>/
```

Configuration: `/etc/default/delatometry`

## Documentation languages

- English: `/docs/en` in the Web UI or `docs/en/` in the repo.
- Ukrainian: `/docs/uk` or `docs/uk/`.
