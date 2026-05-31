# Веб-інтерфейс

Браузерний HMI (`delatometry-webui.service`, порт **80**). FastAPI + Jinja2 + Chart.js; вузол ROS `webui`.

> **Це не Nextion** — серійний дисплей у пакеті `hmi`.

## Сторінки

| Маршрут | Опис |
|---------|------|
| `/dashboard` | Стан хоста, systemd, диск, UART, мережа |
| `/programs` | Список, видалення, експорт ZIP |
| `/program-new` | Майстер нової програми |
| `/program-view`, `/program-edit` | Перегляд і редагування |
| `/experiment` | Графіки LTM / E7-20, ручна ціль |
| `/configuration` | Мережа, env, параметри вузлів |
| `/docs` | Перегляд документації EN / UK |

Мова UI: cookie `delatometry_lang`, `/set-locale/en|uk`.

## Живі дані

- `/ws/dashboard`, `/ws/experiment`
- `/api/experiment/status`
- `/dashboard/snapshot`

## Власність експерименту

Веб-UI **не** планує програми локально. Старт/стоп — у core; вимірювання під час запуску пише core.

## Документація в UI

`/docs` → мова з locale або `/docs/en`, `/docs/uk`. Потрібен пакет **markdown** у venv.

Залежності: `src/webui/requirements.txt`.
