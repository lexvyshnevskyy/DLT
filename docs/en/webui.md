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
| `/program-new` | Wizard (description → steps → E7-20); `?new=1` clears draft |
| `/program-view?id=N` | Read-only detail and run history |
| `/program-edit?id=N` | Edit meta/steps, start/stop run |
| `/experiment` | Live LTM + E7-20 charts, manual heater target |
| `/configuration` | Network, env, node params, topic peek |
| `/docs` | Documentation browser (EN / UK) |

Locale: cookie `delatometry_lang` (`en` / `uk`), `/set-locale/{code}`.

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

When a run ends (stop or natural finish), webui schedules run charts from DB (`_schedule_run_charts_on_finish`).

## Auth

HTTP Basic when `auth_enabled` in node params. Exempt: `/static/`, `/ws/`, `/api/`, `/dashboard/snapshot`. `/docs` requires auth like other pages.

## Dependencies

`src/webui/requirements.txt` — FastAPI, uvicorn, jinja2, psutil, mysql-connector-python, matplotlib, **markdown** (for `/docs`).

## Sudo (optional)

Dashboard service actions need passwordless `systemctl` for the service user — `src/webui/scripts/install_sudoers.sh`.

## i18n

Strings in `webui/locale/en.json` and `uk.json`. Documentation content is separate under `docs/en` and `docs/uk`, linked from `/docs/{lang}/…`.
