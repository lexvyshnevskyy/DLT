To build your ROS project using Catkin, follow these steps:

---

### **1. Navigate to Your Catkin Workspace**
```bash
cd ~/catkin_ws
```

---

### **2. Ensure Dependencies Are Installed**
Run `rosdep` to check for and install missing dependencies:
```bash
rosdep install --from-paths src --ignore-src -r -y
```

This ensures that all required ROS packages and system dependencies are installed.

---

### **3. Build the Workspace**
Use `catkin_make` to compile the workspace:
```bash
catkin_make
```

---

### **4. Source the Workspace**
After building, source the setup file to make sure the built packages are available:
```bash
source devel/setup.bash
```

To avoid sourcing manually every time, add it to your `~/.bashrc`:
```bash
echo "source ~/catkin_ws/devel/setup.bash" >> ~/.bashrc
source ~/.bashrc
```

---

### **5. Verify That Your Package Is Built**
Check if your package is correctly built and recognized by ROS:
```bash
rospack list | grep hmi
```

If the package appears in the list, it is successfully built.

---

### **6. Run Your Node**
Now you can run your node:
```bash
rosrun hmi run.py
```

Or if you are using a launch file:
```bash
roslaunch hmi hmi.launch
```

---

### **Troubleshooting**
#### **1. If `catkin_make` Fails:**
- Check for missing dependencies and install them:
  ```bash
  rosdep install --from-paths src --ignore-src -r -y
  ```
- Make sure you have the required ROS version installed and sourced correctly:
  ```bash
  source /opt/ros/noetic/setup.bash
  ```

#### **2. If Your Node Is Not Found:**
- Ensure the package is inside `~/catkin_ws/src/`
- Rebuild the workspace:
  ```bash
  catkin_make
  ```
- Source the workspace again:
  ```bash
  source devel/setup.bash
  ```

Now your ROS project should be successfully built and ready to run. Let me know if you run into any issues! 🚀