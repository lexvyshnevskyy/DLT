# Апаратні вузли

Датчики та приводи подають дані в **core**, який синхронізує потоки та виконує цикл керування.

## ltm2985_uart

- Основний **канал керування** температурою.
- Служба: `delatometry-ltm2985.service`
- Симулятор: `src/ltm2985_uart/hardware/ltm_nodemcu_simulator/README.md`

## measure_device (E7-20)

Імпедансметр по UART; `msgs/E720` на `/e720`. Служба: `delatometry-measure-device.service`. Розгорт частот E7-20 у веб-UI — лише при `DELATOMETRY_MEASURE_SOURCE=e720`.

## im3536 (Hioki IM3536)

LCR-метр: **RS-232**, **USB** (serial) або **LAN** (TCP); SCPI. Той самий контракт `msgs/E720` на `/im3536`. Вибір у **Конфігурації** або `DELATOMETRY_MEASURE_SOURCE=im3536`. Служба: `delatometry-im3536.service`. Деталі: `src/im3536/README.md`.

## ads1256

Опційний АЦП; `delatometry-ads1256.service` — лише якщо є плата.

## PWM

Core керує PWM при `enable_pwm_controller:=true`.

| Плата | Backend |
|-------|---------|
| Pi 4 і старіші | **pigpio** (`pigpiod`) |
| Pi 5 | **lgpio** (без pigpiod) |

На Pi 5: `dtoverlay=pwm` у `/boot/firmware/config.txt`. Піни за замовч.: GPIO 18, 19.

## Дозволи

Інсталятор: групи `gpio`, `dialout`, `spi`, swap 2 ГБ, UART на GPIO 14/15 для HMI.
