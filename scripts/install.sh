#!/bin/bash
# pigpio
# http://abyz.me.uk/rpi/pigpio/download.html
sudo apt install unzip
wget https://github.com/joan2937/pigpio/archive/master.zip
unzip master.zip
cd pigpio-master
make
sudo make install


# ads packages
sudo apt install python3-pip python3-numpy python3-pigpio git

# todo create pigpiod servioce
sudo systemctl enable pigpiod.service