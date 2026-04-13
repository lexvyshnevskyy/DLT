Back up the original config.txt and cmdline.txt files

sudo cp -pr /boot/firmware/cmdline.txt /boot/firmware/cmdline.txt-orig
sudo cp -pr /boot/firmware/config.txt /boot/firmware/config.txt-orig
Edit /boot/firmware/config.txt to comment out the enable_uart=1 like below,

#enable_uart=1

cmdline=cmdline.txt
Remove the console setting console=serial0,115200 from /boot/firmware/cmdline.txt

Disable the Serial Service which used the miniUART

sudo systemctl stop serial-getty@ttyS0.service
sudo systemctl disable serial-getty@ttyS0.service
sudo systemctl mask serial-getty@ttyS0.service
Add the user which will use the miniUART to tty and dialout group

sudo adduser ${USER} tty
sudo adduser ${USER} dialout
Finally, reboot Ubuntu 20.04, then both hci0 and /dev/ttyS0 can work at the same time for me.