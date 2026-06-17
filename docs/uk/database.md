# База даних

MariaDB зберігає програми, кроки температури, метадані (JSON E7-20), **запуски програм** і **вимірювання**.

## Таблиці (коротко)

| Таблиця | Призначення |
|---------|-------------|
| `programs` | Заголовок програми |
| `program_temp` | Кроки: `t_start`, `t_stop`, `minutes` |
| `program_meta` | Пари ключ/значення (`description`, `experiment_mode`, JSON E7-20) |
| `program_runs` | Кожен запуск: індекс, час, статус |
| `measurements` | Часові ряди, `elapsed_s`, `run_id` |

Повна схема: `src/database/sql/schema.sql`.

## Життєвий цикл запуску

1. **Старт** — core створює рядок `Running` у `program_runs`.
2. **Зразки** — `measurements` з `run_id`; `elapsed_s` від core.
3. **Стоп** — закриття запуску; узгодження «завислих» Running при idle stop.

## ROS

Вузол `database`, сервіс **`/database/query`** (JSON).

Web UI викликає через `asyncio.to_thread`. У `db_control.py` — `_state_lock` для якорів часу.

## Служба та експорт

`delatometry-database.service` має працювати до логування з core. Експорт ZIP у веб-UI — через `export_data.py`.
