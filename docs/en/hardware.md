# Hardware nodes

Sensor and actuator nodes feed **core**, which synchronizes streams and runs the control loop.

## ltm2985_uart

- Primary **control channel** temperature source today.
- Publishes measurements consumed by core for PI and program ticks.
- Service: `delatometry-ltm2985.service`
- Simulator docs: `src/ltm2985_uart/hardware/ltm_nodemcu_simulator/README.md`

## measure_device

- External measurement hardware (serial protocol).
- Service: `delatometry-measure-device.service`

## ads1256

- Optional high-resolution ADC path.
- Service: `delatometry-ads1256.service` (enable only when hardware present)
- May share the measurement topic pattern with LTM for future unified control channel.

## PWM / heating

Core optionally uses **pigpio** for PWM when `enable_pwm_controller:=true`. Manual targets from `/experiment/manual` in webui are forwarded to core; blocked during active programs.

## Groups and permissions

`scripts/install.sh` may add the service user to `gpio`, `dialout`, etc. UART nodes need read/write on `/dev/tty*`.

## Legacy hardware notes

Older markdown in `documents/Hardware.md` and `documents/UART.md` may still help for board-specific wiring; verify against current ROS 2 packages.
