To automatically start your ROS project on system boot, you can create a systemd service that launches your ROS nodes or launch files. Here’s how to set it up:

---

### **1. Create a ROS Launch File (if not already done)**
If your ROS project uses a single node or multiple nodes, you should have a launch file in your package. For example, `hmi.launch` might already exist in the `launch` directory of your package.

If not, create one in your package:
```bash
nano ~/catkin_ws/src/hmi/launch/hmi.launch
```

Example `hmi.launch` file:
```xml
<launch>
  <node pkg="hmi" type="run.py" name="hmi_node" output="screen" />
</launch>
```

Save and exit.

---

### **2. Create a Shell Script to Launch ROS**
Create a script that sources the workspace and runs the ROS launch file:
```bash
nano ~/catkin_ws/start_hmi.sh
```

Add the following content:
```bash
#!/bin/bash
source /opt/ros/noetic/setup.bash   # Source ROS setup
source ~/catkin_ws/devel/setup.bash # Source workspace setup
export PYTHONPATH=$PYTHONPATH:/home/ubuntu/catkin_ws/src/hmi/src # Ensure PYTHONPATH is set
roslaunch hmi hmi.launch
```

Save and exit.

Make the script executable:
```bash
chmod +x ~/catkin_ws/start_hmi.sh
```

---

### **3. Create a Systemd Service File**
Create a service file to run the script on boot:
```bash
sudo nano /etc/systemd/system/hmi.service
```

Add the following content:
```ini
[Unit]
Description=Start HMI ROS Project
After=network.target

[Service]
ExecStart=/bin/bash /home/ubuntu/catkin_ws/start_hmi.sh
Restart=always
User=ubuntu
Environment=DISPLAY=:0
Environment=ROS_MASTER_URI=http://localhost:11311
Environment=ROS_HOSTNAME=localhost

[Install]
WantedBy=multi-user.target
```

Save and exit.

---

### **4. Enable and Start the Service**
Enable the service to start on boot:
```bash
sudo systemctl enable hmi.service
```

Start the service now (for testing):
```bash
sudo systemctl start hmi.service
```

Check the status to ensure it's running:
```bash
sudo systemctl status hmi.service
```

---

### **5. Reboot and Verify**
Reboot your system to ensure the ROS project starts automatically:
```bash
sudo reboot
```

After reboot, verify the service is running:
```bash
sudo systemctl status hmi.service
```

---

### **Optional Debugging**
- Check logs if something goes wrong:
  ```bash
  journalctl -u hmi.service
  ```

This setup ensures your ROS project starts automatically on system boot. Let me know if you need further assistance!