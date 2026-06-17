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

Review `/etc/default/delatometry` for workspace path, venv, DB password, and `ROS_DOMAIN_ID` mismatches between nodes.
