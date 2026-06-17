# Веб-інтерфейс

Браузерний HMI (`delatometry-webui.service`, порт **80**). FastAPI + Jinja2 + Chart.js; вузол ROS `webui`.

> **Це не Nextion** — серійний дисплей у пакеті `hmi`.

## Сторінки

| Маршрут | Опис |
|---------|------|
| `/dashboard` | Стан хоста, systemd, диск, UART, мережа |
| `/programs` | Список, видалення, експорт ZIP |
| `/program-new` | Майстер нової програми (режим, розгони, розгорт E7-20) |
| `/program-view?id=N` | Перегляд програми та історія запусків |
| `/program-edit?id=N` | Редагування, старт/стоп запуску |
| `/program-run?program_id=N&run_id=M` | Деталі запуску, графіки, таблиця вимірювань |
| `/experiment` | Графіки LTM / E7-20, ручна ціль |
| `/configuration` | Мережа, env, параметри вузлів, **джерело імпедансу**, транспорт IM3536 |
| `/docs` | Перегляд документації EN / UK |

Мова UI: cookie `delatometry_lang`, `/set-locale/en|uk`.

## Майстер програми

- **Режим експерименту** — `default`, `measure_only`, `measure_ltm`.
- **Кроки температури** — обов’язкові для `default`; для часових режимів — лише тривалість.
- **Розгорт E7-20** — лише коли джерело `e720`.

## Сторінка конфігурації

- `DELATOMETRY_MEASURE_SOURCE` — `e720` або `im3536`
- Параметри IM3536: інтерфейс (RS-232 / USB / LAN), порт, швидкість, хост, термінатор

## Живі дані

- `/ws/dashboard`, `/ws/experiment`
- `/api/experiment/status`
- `/dashboard/snapshot`

## Власність експерименту

Веб-UI **не** планує програми локально. Старт/стоп — у core; вимірювання під час запуску пише core.

## Графіки запусків

PNG зберігаються в **`DELATOMETRY_WEBUI_RUN_CHARTS_DIR`** (`/var/lib/delatometry/run_charts`). Після перезавантаження відкрийте запуск або натисніть **Створити графіки** — дані з БД.

## Документація в UI

`/docs` → мова з locale або `/docs/en`, `/docs/uk`. Потрібен пакет **markdown** у venv.

Залежності: `src/webui/requirements.txt`.
