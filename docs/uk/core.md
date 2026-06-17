# Вузол core

Пакет `core` — **єдине джерело правди** для температурних програм, PI-керування та запису вимірювань під час запуску.

## Режими експерименту

У `program_meta` зберігається `experiment_mode` (майстер програми у веб-UI):

| Режим | Керування температурою | LTM у журналі | Тік програми |
|-------|------------------------|---------------|--------------|
| `default` | Так (PWM + PI) | Так | Кожен зразок LTM |
| `measure_only` | Ні | Ні | Таймер (`measurement_log_interval_sec`) |
| `measure_ltm` | Ні | Так | Таймер |

- **default** — класичний розгін з нагрівом; watchdog LTM увімкнено.
- **measure_only** / **measure_ltm** — журнал імпедансу за часом; без PWM; планувальник працює без `enable_pwm_controller`.

У JSON статусу: `experiment_mode` у блоці `program`.

## Джерело імпедансу

Параметр `measure_source` у `core.params.yaml` (перевизначається `DELATOMETRY_MEASURE_SOURCE`):

- `e720` — топік `/e720` від `measure_device`
- `im3536` — топік `/im3536` від `im3536`

Допоміжний модуль: `core/measure_source.py`.

## Увімкнення функцій

- `enable_pwm_controller` — PWM нагрівача (pigpio)
- `enable_database_client` — клієнт `/database/query`
- `enable_program_scheduler` — `ProgramExperimentManager` (часові режими без PWM)

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
