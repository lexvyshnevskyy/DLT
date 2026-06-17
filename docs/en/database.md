# Database

MariaDB stores programs, temperature steps, metadata (including E7-20 JSON), **program runs**, and **measurements**.

## Schema (summary)

| Table | Purpose |
|-------|---------|
| `programs` | Program header (`ID`, `DateTime`, `Status`) |
| `program_temp` | Ramp steps: `t_start`, `t_stop`, `minutes` per `program_id` |
| `program_meta` | Key/value blobs (e.g. `description`, `experiment_mode`, E7-20 sweep JSON) |
| `program_runs` | Each execution: `run_index`, `started_at`, `stopped_at`, `status` |
| `measurements` | Time series: `elapsed_s`, temps, freqs, channels; optional `run_id` |

Full DDL: `src/database/sql/schema.sql`.

## Run lifecycle

1. **Start** — core creates a `program_runs` row (`Running`).
2. **Samples** — `measurements` rows reference `program_id` and `run_id`; `elapsed_s` from core when available.
3. **Stop / finish** — run marked stopped; stale `Running` rows reconciled on idle stop.

## ROS interface

The `database` node exposes **`/database/query`** (JSON in / JSON out), same pattern as legacy ROS 1.

Typical operations (conceptual):

- `program_list`, `program_get`, `program_insert`, `program_update`, …
- `measurement_insert`, `measurement_list`, aggregates for charts
- `program_run_*` helpers for run history

Web UI calls these through `WebHMINode` async bridges (`asyncio.to_thread`).

## Thread safety

`db_control.py` protects elapsed-time anchor state with `_state_lock` so concurrent status reads and inserts stay consistent.

## Configuration

Credentials and DSN typically come from `/etc/default/delatometry` and database node params. Default install user is often `delatometry` / `delatometry` (change in production).

## Service

`delatometry-database.service` — must be running before core can log measurements.

## Export

Web UI **Export ZIP** reads measurements and program meta through the database node (`export_data.py`), with unique CSV names and truncation warnings when limits apply.
