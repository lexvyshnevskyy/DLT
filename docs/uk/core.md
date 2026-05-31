# Вузол core

Пакет `core` — **єдине джерело правди** для температурних програм, PI-керування та запису вимірювань під час запуску.

## Увімкнення функцій

- `enable_pwm_controller` — PWM нагрівача (pigpio)
- `enable_database_client` — клієнт `/database/query`
- `enable_program_scheduler` — `ProgramExperimentManager`

Під час програми ручний PWM блокується відповідно до політики core.

## Команди програм (`/core/query`)

```json
{"program": {"cmd": "start", "program_id": 4}}
{"program": {"cmd": "stop", "program_id": 4}}
{"program": {"cmd": "stop_all"}}
{"program": {"cmd": "status"}}
```

Веб-UI та HMI надсилають еквівалентні команди через ROS — без локальної логіки розгону.

## Топік статусу

`/core/experiment/status` — JSON у `std_msgs/String`:

- `program`, `temperature_control`, `ltm_summary`

> У продакшені використовуйте **`/core/experiment/status`**, не застарілий шлях без префікса namespace.

## Цикл керування

- Зразки каналу керування (LTM) → PI і кроки програми.
- `RLock` на start/stop/tick.
- Перехід кроку: `target_k`, `reset_integral`.

## Журнал вимірювань

`measurement_insert` з **`elapsed_s` від core**; коміт на зразок. При завершенні вузла — дренаж черги БД.

## Захисна логіка

| Поведінка | Навіщо |
|-----------|--------|
| Watchdog LTM | Зупинка, якщо канал керування «замовк» |
| Блок ручного PWM | Конфлікт з програмою |
| Валідація перед stop іншої | Не вбити хороший запуск через помилку старту |
| Завершення в БД | Не скидати core при помилці finish |
| Відкат невдалого старту | Прибрати сирі `program_runs` |

Параметри: `src/core/config/core.params.yaml`. Служба: `delatometry-core.service`.
