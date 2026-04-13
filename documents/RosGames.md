To launch ROS, open a new Linux terminal window and type the following command:
```shell
  roscore
```
All work correctly if you'll got next output:

```shell
    ubuntu@delatometr:~/ros$ roscore
    ... logging to /home/ubuntu/.ros/log/3603a9a2-80b9-11ee-b510-6d1007c98fd4/roslaunch-delatometr-14974.log
    Checking log directory for disk usage. This may take a while.
    Press Ctrl-C to interrupt
    Done checking log file disk usage. Usage is <1GB.
    
    started roslaunch server http://delatometr:37721/
    ros_comm version 1.16.0
    
    
    SUMMARY
    ========
    
    PARAMETERS
     * /rosdistro: noetic
     * /rosversion: 1.16.0
    
    NODES
    
    auto-starting new master
    process[master]: started with pid [14984]
    ROS_MASTER_URI=http://delatometr:11311/
    
    setting /run_id to 3603a9a2-80b9-11ee-b510-6d1007c98fd4
    process[rosout-1]: started with pid [14994]
    started core service [/rosout]
```

### Useful commands ###
 * `roscore` Run master process
 * `rostopic list` view active topics 

### Let's create dummy project ###
    * [Official manual](http://wiki.ros.org/ROS/Tutorials/WritingPublisherSubscriber%28python%29)
    * [Official manual/creating package](http://wiki.ros.org/ROS/Tutorials/CreatingPackage)

### Talker/listener example ###

1. Lets create our package
    ```shell
      catkin_create_pkg talker_listener std_msgs rospy roscpp
    ```
2. Download and extract example source code to working dir(./talker_listener/src/) [Source code](examples/talker.py)
3. `chmod 777 talker.py`
4. Download and extract example source code to working dir [Source code](examples/listener.py)
5. `chmod 777 listener.py`
6. Then, edit the catkin_install_python() call in your CMakeLists.txt so it looks like the following: 
    ```cmake
        catkin_install_python(PROGRAMS src/talker.py src/listener.py
            DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
        )
    ```
7. Build our boolshit `catkin_make`

### Lets Run our Boolshit ###

1. `roscore` 
2. `rosrun talker_listener talker.py` 


## have a fun