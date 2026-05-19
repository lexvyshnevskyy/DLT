#!/bin/bash

#echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
#source ~/.bashrc

# source your ROS environment first
source /opt/ros/jazzy/setup.bash

# build everything
colcon build --symlink-install

source ~/ros2_delatometry/install/setup.bash