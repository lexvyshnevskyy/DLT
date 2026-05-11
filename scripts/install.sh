#!/bin/bash
set -e

echo "=== ROS 2 Jazzy Minimal Install on Debian Trixie arm64 ==="

export DEBIAN_FRONTEND=noninteractive

# Update system
sudo apt update
sudo apt upgrade -y

# Install prerequisites
sudo apt install -y \
  curl \
  gnupg \
  lsb-release \
  ca-certificates


echo "=== Installing pigpio and ADS dependencies ==="

# Update system
sudo apt update

# Install prerequisites
sudo apt install -y unzip git python3-pip python3-numpy python3-pigpio

# Install latest pigpio from source (recommended on Raspberry Pi)
echo "Building and installing pigpio from source..."
if [ ! -d "pigpio-master" ]; then
    wget -q https://github.com/joan2937/pigpio/archive/master.zip -O pigpio-master.zip
    unzip -q pigpio-master.zip
fi

cd pigpio-master
make -j2          # Use 2 cores (safe for Pi)
sudo make install
sudo ldconfig

# Enable and start pigpiod daemon
echo "Enabling pigpiod service..."
# Create the systemd service file
sudo tee /lib/systemd/system/pigpiod.service > /dev/null << EOF
[Unit]
Description=Daemon required to control GPIO pins via pigpio
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/pigpiod -t 0
ExecStop=/bin/kill -SIGTERM \$MAINPID
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable --now pigpiod.service

# Check status
echo "=== pigpiod Status ==="
systemctl status pigpiod --no-pager

# Check status
echo "pigpiod status:"
systemctl status pigpiod --no-pager -l

# Optional: Install useful Python packages
echo "Installing extra Python packages..."
pip3 install --break-system-packages --upgrade \
    pigpio \
    adafruit-circuitpython-ads1x15 \
    numpy \
    rpi.gpio

echo "=== Installation Finished! ==="
echo "You can test pigpio with: pigs t"
echo "pigpiod is running: $(systemctl is-active pigpiod)"

# Install MySQL-compatible server
# On Debian this is usually MariaDB via default-mysql-server.
echo "Installing MySQL/MariaDB server..."
sudo apt install -y default-mysql-server default-mysql-client

sudo systemctl enable mariadb || true
sudo systemctl restart mariadb || true

# Configure root user with empty password
# WARNING: insecure. Use only for local/dev/test systems.
echo "Configuring MySQL/MariaDB root user with empty password..."

sudo mysql <<'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED BY '';
FLUSH PRIVILEGES;
SQL

echo "MySQL/MariaDB root password is now empty."
echo "Test with:"
echo "  mysql -u root"

# 1. Add rospian signing key
echo "Adding rospian repository key..."
curl -fsSL https://rospian.github.io/rospian-repo/rospian-archive-keyring.asc \
  | gpg --dearmor | sudo tee /usr/share/keyrings/rospian-archive-keyring.gpg > /dev/null

# 2. Add the APT repository
echo "Adding rospian ROS 2 Jazzy repository..."
echo "deb [arch=arm64 signed-by=/usr/share/keyrings/rospian-archive-keyring.gpg] https://rospian.github.io/rospian-repo trixie-jazzy main" \
  | sudo tee /etc/apt/sources.list.d/rospian.list > /dev/null

# 3. Update package list
sudo apt update

# 4. Install minimal ROS 2 ros-base
echo "Installing ros-jazzy-ros-base minimal..."
sudo apt install -y ros-jazzy-ros-base

# Optional but highly recommended tools
sudo apt install -y \
  python3-colcon-common-extensions \
  python3-rosdep \
  python3-vcstool

# Initialize rosdep
echo "Initializing rosdep..."
sudo rosdep init || true
rosdep update

# 5. Environment setup
echo "Setting up environment..."

if ! grep -q "source /opt/ros/jazzy/setup.bash" ~/.bashrc; then
  echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
fi

# Source immediately for this session
source /opt/ros/jazzy/setup.bash

echo "=== Installation completed! ==="
echo ""
echo "Test ROS 2 with:"
echo "  source ~/.bashrc"
echo "  ros2 run demo_nodes_cpp talker"
echo ""
echo "In another terminal:"
echo "  ros2 run demo_nodes_cpp listener"
echo ""
echo "Test pigpiod with:"
echo "  systemctl status pigpiod"
echo ""
echo "Test MySQL/MariaDB with:"
echo "  mysql -u root"