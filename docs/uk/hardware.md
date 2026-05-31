# Апаратні вузли

Датчики та приводи подають дані в **core**, який синхронізує потоки та виконує цикл керування.

## ltm2985_uart

- Основний **канал керування** температурою.
- Служба: `delatometry-ltm2985.service`
- Симулятор: `src/ltm2985_uart/hardware/ltm_nodemcu_simulator/README.md`

## measure_device

Зовнішні вимірювання; `delatometry-measure-device.service`.

## ads1256

Опційний АЦП; `delatometry-ads1256.service` — лише якщо є плата.

## PWM

Core + pigpio при `enable_pwm_controller:=true`. Ручна ціль з `/experiment/manual` — у core; під програмою блокується.

## Дозволи

Користувач служби в групах `gpio`, `dialout` тощо; доступ до `/dev/tty*`.
