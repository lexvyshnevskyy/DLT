* **scripts/install.sh** (project root installer)
  * interactive **whiptail** menu:
    * **Full install from scratch** — apt deps, MariaDB, venv, all pip requirements, rosdep, colcon build all nodes, systemd, webui sudoers
    * **Rebuild packages** — rebuild all nodes, refresh services, restart
  * non-interactive: `INSTALL_MODE=scratch` or `INSTALL_MODE=rebuild`
  * covers packages: msgs, database, core, ltm2985_uart, measure_device, ads1256, hmi, webui
* setup_dlt.sh
  * updates main repo
  * updates nested git repos/submodules
  * installs Python requirements
  * runs rosdep
  * runs colcon build --symlink-install
  * installs systemd units
  * enables/restarts the default stack
* update_rebuild_restart.sh
  * starts ssh-agent / ssh-add
  * pulls latest code
  * rebuilds
  * reinstalls service units
  * restarts enabled services

## Web UI

* Package: `src/webui` — Gradio interface on port 7860 (`ros2 launch webui webui.launch.py`)
* Requires: `pip install -r src/webui/requirements.txt` (gradio, psutil)
* Optional sudoers for service control and Wi-Fi: `sudo bash src/webui/scripts/install_sudoers.sh`
* Enable heater control: `DELATOMETRY_CORE_ENABLE_PWM_CONTROLLER=true` in `/etc/default/delatometry`