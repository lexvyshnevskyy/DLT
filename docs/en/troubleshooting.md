# Troubleshooting

## Web UI shows “connecting” or empty experiment

1. Check core is running: `systemctl status delatometry-core`
2. Confirm LTM publishes: `ros2 topic echo /core/experiment/status --once`
3. Restart webui after deploy: `sudo systemctl restart delatometry-webui`

## Program start hangs or never begins

- Ensure a **clean rebuild** of `core` on the Pi (stale install with blocking `future.result(timeout=)` in service callbacks caused deadlocks on `program.start`).
- Verify `enable_program_scheduler`, PWM, and database client are enabled.
- Check LTM watchdog — control channel must update; see `core.params.yaml`.

## Run stuck “Running” in DB but idle

- Core reconciles stale runs on stop; restart core if needed after an unclean shutdown.
- Inspect `program_runs` in MariaDB for orphan `Running` rows.

## No measurements in database

- `delatometry-database.service` must be active.
- Core logs inserts only during an active run with DB client enabled.
- Check core logs: `scripts/systemd/logs.sh delatometry-core`

## HMI out of sync with actual run

- HMI should follow `/core/experiment/status`; restart `delatometry-hmi` after core fixes.
- Do not rely on local HMI state across core restarts.

## Documentation 404 in browser

- Rebuild webui so `share/webui/docs` is installed: `colcon build --packages-select webui`
- Install markdown: `pip install markdown>=3.5`

## Build / colcon errors

```bash
source /opt/ros/jazzy/setup.bash
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
```

## Logs and status

```bash
~/ros2_delatometry/scripts/systemd/status.sh
~/ros2_delatometry/scripts/systemd/logs.sh delatometry-core
journalctl -u delatometry-webui -f
```

## Hotspot has SSID but clients get no IP

1. Install **dnsmasq** and the hotspot unit: `sudo apt install dnsmasq`, then re-run `scripts/install.sh` (rebuild) or `scripts/systemd/install_services.sh`.
2. Reinstall webui sudoers: `sudo bash src/webui/scripts/install_sudoers.sh`
3. Check DHCP service: `systemctl status delatometry-hotspot-dnsmasq.service`
4. Config must exist after enable: `/etc/delatometry/hotspot-dnsmasq.conf`
5. Logs: `journalctl -u delatometry-hotspot-dnsmasq.service -f`

## Configuration file

Review `/etc/default/delatometry` for workspace path, venv, DB password, `ROS_DOMAIN_ID`, Pi model (`DELATOMETRY_RPI_MODEL`), PWM backend, HMI UART port, and run charts directory.

## PWM / heater control not working

| Symptom | Pi 4 | Pi 5 |
|---------|------|------|
| Dashboard mentions pigpiod | Start: `sudo systemctl enable --now pigpiod` | **Do not use pigpiod** — it fails on Pi 5 |
| PWM enabled but no output | Enable PWM in **Configuration → Core**, restart `delatometry-core` | Install `python3-lgpio`, add `dtoverlay=pwm` to `/boot/firmware/config.txt`, reboot |
| Core log `backend=lgpio` | — | Expected on Pi 5 |
| Core log `bad PWM micros` | — | Update `core` package (lgpio zero-duty fix), rebuild, restart core |

Re-run installer with correct model: `RPI_MODEL=rpi5 INSTALL_MODE=rebuild bash scripts/install.sh`

## pigpiod failed on Raspberry Pi 5

Expected. Stock `pigpiod` does not support Pi 5 (revision `d04170`). Use **`lgpio`** instead:

```bash
sudo systemctl disable --now pigpiod
sudo apt install python3-lgpio
grep PWM /etc/default/delatometry   # enable DELATOMETRY_CORE_ENABLE_PWM_CONTROLLER=true
sudo systemctl restart delatometry-core
```

## Program run charts missing after reboot

Charts are stored under **`/var/lib/delatometry/run_charts`** (not `/tmp`). If missing:

1. Ensure env: `DELATOMETRY_WEBUI_RUN_CHARTS_DIR="/var/lib/delatometry/run_charts"`
2. Re-run `scripts/systemd/install_services.sh` or full install
3. Open the run in Web UI — charts regenerate from DB automatically, or click **Generate charts**

Rebuild webui after updates: `colcon build --packages-select webui && sudo systemctl restart delatometry-webui`

## HMI / Nextion no serial data

Installer enables UART on **GPIO 14/15** and sets `DELATOMETRY_HMI_PORT`. After install:

```bash
grep HMI_PORT /etc/default/delatometry
ls -l /dev/serial0 /dev/ttyAMA*
groups    # should include dialout
sudo reboot   # if UART was just enabled
journalctl -u delatometry-hmi -n 30
```

If needed, re-apply UART setup: `INSTALL_MODE=rebuild bash scripts/install.sh` on the Pi.
