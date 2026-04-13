TODO

#### If your docker already installed and image exist: go to step 6
1. If you have installed docker on your system Than run next commands
    ```shell
      sudo apt-get install qemu binfmt-support qemu-user-static # Install the qemu packages
      docker run --rm --privileged multiarch/qemu-user-static --reset -p yes # This step will execute the registering scripts
    ```

2. If your docker are really old: Remove it by next commands
    ```shell
      for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
    ```

3. Install latest required packages with qemu by run next script
    `docker->rpi->arm64v8->install_debian.sh`
    or running next script
    ```shell
      ./docker/rpi/arm64v8/install_debian.sh 
    ```

4. Test if docker installed propetly
    ```shell
      sudo docker run hello-world
    ```

5. Build docker
    ```shell
      ./docker/rpi/arm64v8/build.bash 
    ```

6. Run image
    ```shell
      ./docker/rpi/arm64v8/run.bash
    ```
You'll got terminal window to your container
