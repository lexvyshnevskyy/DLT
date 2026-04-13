# TODO
update Readme and documentation as for 01.01.2026 absolute


# README #
This is repository for Delatometry project.

## Software requirements ##
* Ubuntu/debian 22 
* Ros2 (refer to documentation)

## Project Structure ##
* [README.md](README.md)
* deploy.sh : run this script to prepare project tree
* documentation
    - [Deploy RPI/Ubuntu packages](/documents/UbuntuDeploy.md)
    - [Hardware requirement](/documents/Hardware.md)
    - [Docker structure and purpose](/documents/Docker.md)
    - [Testing and examples](/documents/RosGames.md)
* docker
    - rpi
        + arm64v8
            * build.bash will build docker image named as "delatometr"
            * run.bush run container in interactive mode. Contain of folder root/ros will be mount inside container like volume
            * Dockerfile : descriptor of container
* hmi : external repository for HMI interface. Check deploy.sh
* ros  : external repository for HMI interface. Check deploy.sh
* install_rpi :scripts for rpi software installation. Check documentation
    - 999_decompress_rpi_kernel : require for ubuntu update. as kernel is compressed and loader require uncompressed image
    - auto_decompress_kernel : first boot decompression script
    - config.txt : board configuration with commands for raspbery pi4. refer to correspondent line if you plan to use different board
    - install.sh : run this script to configure bord
    - network-config : default wireless network hide inside this file
    - rpi : ssh key for read only access to repo
    - rpi.pub : ssh public readonly key
    - shadow : preconfigured password storage. DO NOT EDIT
    - user-data : script for default boot parameters like user-name...

## Deploy and run
### Download HMI and Source repos by running command
```shell
./deploy.sh
```

### Each directory has its own git
* rpi : root of project
    - hmi : root of hmi project
    - ros : root of ros project
