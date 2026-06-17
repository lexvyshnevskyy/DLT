# Hardware nodes

Sensor and actuator nodes feed **core**, which synchronizes streams and runs the control loop.

## ltm2985_uart

- Primary **control channel** temperature source today.
- Publishes measurements consumed by core for PI and program ticks.
- Service: `delatometry-ltm2985.service`
- Simulator docs: `src/ltm2985_uart/hardware/ltm_nodemcu_simulator/README.md`

## measure_device (E7-20)

- Serial impedance meter; publishes `msgs/E720` on `/e720`.
- E7-20 frequency sweep commands from Web UI when `DELATOMETRY_MEASURE_SOURCE=e720`.
- Service: `delatometry-measure-device.service`

## im3536 (Hioki IM3536)

- LCR meter over **RS-232**, **USB** (serial), or **LAN** (TCP); Hioki SCPI (`:MEASure?`, `:FREQuency?`).
- Publishes the same `msgs/E720` contract on `/im3536` for core fusion.
- Topics: `im3536/raw`, `im3536/connected`; offline frame id `im3536_offline`.
- Select in Web UI **Configuration** or `DELATOMETRY_MEASURE_SOURCE=im3536`.
- Service: `delatometry-im3536.service`
- Package docs: `src/im3536/README.md`

## ads1256

- Optional high-resolution ADC path.
- Service: `delatometry-ads1256.service` (enable only when hardware present)
- May share the measurement topic pattern with LTM for future unified control channel.

## PWM / heating

Core optionally uses **pigpio** for PWM when `enable_pwm_controller:=true`. Manual targets from `/experiment/manual` in webui are forwarded to core; blocked during active programs.

## Groups and permissions

`scripts/install.sh` may add the service user to `gpio`, `dialout`, etc. UART nodes need read/write on `/dev/tty*`.
