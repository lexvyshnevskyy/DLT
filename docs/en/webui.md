# Web UI

Browser-based HMI (`delatometry-webui.service`, default **port 80**). FastAPI + Jinja2 + Chart.js; ROS node `webui` bridges DB and core.

> **Not the Nextion HMI** — serial display is package `hmi`.

## Entry points

- Installed: `install/webui/lib/webui/run.py`
- Launch: `ros2 launch webui webui.launch.py`
- App factory: `webui/web_app.py` → `create_app(WebHMINode)`

## Pages

| Route | Description |
|-------|-------------|
| `/` | Redirect → `/dashboard` |
| `/dashboard` | Host stats, systemd units, disk, UART, network, logs |
| `/programs` | List, delete, export ZIP |
| `/program-new` | Wizard (description, experiment mode, steps, E7-20 sweep) |
| `/program-view?id=N` | Read-only detail and run history |
| `/program-run?program_id=N&run_id=M` | Run detail, temperature/frequency charts, measurements |
| `/program-edit?id=N` | Edit meta/steps/mode, start/stop run |
| `/experiment` | Live LTM + impedance charts, manual heater target |
| `/configuration` | Network, env, node params, **impedance source**, IM3536 transport |
| `/docs` | Documentation browser (EN / UK) |

Locale: cookie `delatometry_lang` (`en` / `uk`), `/set-locale/{code}`.

## Program wizard

- **Experiment mode** — `default` (heating + LTM), `measure_only` (impedance vs time), `measure_ltm` (impedance + LTM vs time).
- **Temperature steps** — required for `default`; for timed modes, duration steps only (no ramp targets applied).
- **E7-20 sweep** — shown only when impedance source is E7-20 (`DELATOMETRY_MEASURE_SOURCE=e720`).

## Configuration page

- `DELATOMETRY_MEASURE_SOURCE` — `e720` (E7-20) or `im3536` (Hioki IM3536)
- IM3536: interface (RS-232 / USB / LAN), port, baud rate, LAN host/port, SCPI terminator

## Live data

| Route | Type | Role |
|-------|------|------|
| `/dashboard/snapshot` | GET JSON | Dashboard fallback polling |
| `/api/dashboard/snapshot` | Alias | Same payload |
| `/ws/dashboard` | WebSocket ~1 Hz | Dashboard live |
| `/ws/experiment` | WebSocket | Experiment page streams |
| `/api/experiment/status` | GET JSON | Core experiment snapshot |

## Experiment ownership

Web UI **does not** run a local program scheduler. Starting a program sends `program.start` to core; stopping uses `ui_stop_program_by_id` on edit routes. Measurement logging during runs was removed from webui — core writes samples.

## Charts on finish

When a run ends, webui generates PNG charts from the database into **`DELATOMETRY_WEBUI_RUN_CHARTS_DIR`** (default `/var/lib/delatometry/run_charts`). Charts survive reboots (unlike old `/tmp` storage).

- Opening a finished run **auto-regenerates** missing charts from DB measurements.
- **Generate charts** on the run page rebuilds synchronously (no manual browser refresh needed).
- If charts are still generating after a run stops, the page polls and reloads automatically.

Export ZIP includes chart PNGs when present.

## Auth

HTTP Basic when `auth_enabled` in node params. Exempt: `/static/`, `/ws/`, `/api/`, `/dashboard/snapshot`. `/docs` requires auth like other pages.

## Dependencies

`src/webui/requirements.txt` — FastAPI, uvicorn, jinja2, psutil, mysql-connector-python, matplotlib, **markdown** (for `/docs`).

## Sudo (optional)

Dashboard service actions need passwordless `systemctl` for the service user — `src/webui/scripts/install_sudoers.sh`.

## i18n

Strings in `webui/locale/en.json` and `uk.json`. Documentation content is separate under `docs/en` and `docs/uk`, linked from `/docs/{lang}/…`.
