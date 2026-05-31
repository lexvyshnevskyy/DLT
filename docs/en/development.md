# Development

## Workspace conventions

- ROS 2 packages under `src/<name>/`
- Python packages use `ament_python_install_package`
- Prefer extending existing helpers over duplicating experiment logic in webui

## Building one package

```bash
source /opt/ros/jazzy/setup.bash
cd ~/ros2_delatometry
colcon build --packages-select webui --symlink-install
source install/setup.bash
```

## Running nodes manually

```bash
source install/setup.bash
ros2 launch core core.launch.py
ros2 launch webui webui.launch.py
```

Use the same `/etc/default/delatometry` environment as systemd for parity.

## Editing documentation

1. Edit Markdown in `docs/en/` and `docs/uk/` (keep `docs/manifest.json` in sync).
2. Rebuild webui to install docs to `share/webui/docs`.
3. Open `/docs` in the browser.

Ukrainian pages should mirror English slugs (same filenames in `docs/uk/`).

## Testing program flow

1. Create program in web UI wizard (40–1600 K chained steps).
2. Start from program edit page — core should publish running status.
3. Watch `/core/experiment/status` and DB `program_runs` / `measurements`.
4. Stop — charts scheduled, run row closed.

## Removed legacy code

Do not reintroduce:

- `experiment_runner.py` in webui
- Gradio UI (`ui_app.py`, `ui_*_page.py`)
- Local webui program scheduler or `ui_tick_*` handlers

## Pi deploy pattern

```bash
# From dev machine
scp -r src/core src/webui pi@192.168.144.170:~/ros2_delatometry/src/
ssh pi@192.168.144.170 'cd ~/ros2_delatometry && colcon build --packages-select core webui && sudo systemctl restart delatometry-core delatometry-webui'
```

## Useful ROS commands

```bash
ros2 service call /core/query ...
ros2 topic echo /core/experiment/status
ros2 node list
```

## Package README stubs

Each `src/*/README.md` points here for detail; avoid duplicating long route tables in multiple files.
