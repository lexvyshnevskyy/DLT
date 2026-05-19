* install.sh
  * installs ROS 2 minimal (ros-base)
  * installs MySQL server/client
  * installs pigpio and Python/system dependencies
  * initializes rosdep
  * creates /etc/delatometry/delatometry.env
  * creates MySQL DB/user automatically
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