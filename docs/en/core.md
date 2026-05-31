# Core node

The `core` package is the **single source of truth** for running temperature programs, PI control, and measurement inserts during a run.

## Enable features

In launch / params:

- `enable_pwm_controller` — pigpio PWM for heater
- `enable_database_client` — `/database/query` client
- `enable_program_scheduler` — `ProgramExperimentManager`

Manual PWM and program control are blocked appropriately while a program runs.

## Program commands (`/core/query`)

JSON examples on the core query service:

```json
{"program": {"cmd": "start", "program_id": 4}}
{"program": {"cmd": "stop", "program_id": 4}}
{"program": {"cmd": "stop_all"}}
{"program": {"cmd": "status"}}
```

Web UI and HMI send equivalent commands through their ROS bridges — they do not implement ramp logic locally.

## Status topic

`std_msgs/String` on **`/core/experiment/status`** (with namespace `/core`):

- `program` — id, step, running state
- `temperature_control` — PI / manual target / PWM
- `ltm_summary` — recent LTM snapshot for dashboards

> **Note:** Some older configs mention `experiment/status` without the `/core` prefix. Production uses `/core/experiment/status`; webui subscribes to the namespaced topic.

## Control loop

- **Worker:** `TemperatureControlWorker` (threaded) driven by control-channel samples.
- **Programs:** `ProgramExperimentManager` + `program_experiment` step machine.
- **Step advance:** Includes `target_k` and `reset_integral` on transitions.
- **Locking:** Start/stop/tick under `RLock` to avoid races with HMI and web UI.

## Measurement logging

During a run, core inserts rows via `measurement_insert` with **core-supplied `elapsed_s`** (single elapsed clock). Commits are per sample (no webui bulk queue).

On shutdown, core drains pending measurement DB work.

## Safety behaviors

| Behavior | Purpose |
|----------|---------|
| LTM watchdog | Fails program if control channel stops updating |
| Block manual PWM during program | Prevents operator override conflicts |
| Start validation before stop-other | Avoids aborting a good run due to bad start params |
| Finish persistence | If DB finish fails, core state is not silently cleared |
| Failed start rollback | Orphan `program_runs` rows are reconciled |

## Parameters

See `src/core/config/core.params.yaml` for PI gains, topic remaps, watchdog timeout, and feature flags.

## Package entry

Built with `colcon build --packages-select core`. Service: `delatometry-core.service`.
