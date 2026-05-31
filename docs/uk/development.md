# Розробка

## Збірка одного пакета

```bash
source /opt/ros/jazzy/setup.bash
colcon build --packages-select webui --symlink-install
source install/setup.bash
```

## Редагування документації

1. `docs/en/` та `docs/uk/` + `docs/manifest.json`
2. `colcon build --packages-select webui`
3. Відкрити `/docs`

Слаги сторінок в обох мовах однакові.

## Заборонено повертати

- `experiment_runner.py` у webui
- Gradio UI
- Локальний планувальник або `ui_tick_*` у webui

## Деплой на Pi

```bash
scp -r src/core src/webui pi@host:~/ros2_delatometry/src/
ssh pi@host 'cd ~/ros2_delatometry && colcon build --packages-select core webui && sudo systemctl restart delatometry-core delatometry-webui'
```

## Корисні команди ROS

```bash
ros2 topic echo /core/experiment/status
ros2 service call /core/query ...
```

Деталі пакетів — у `docs/uk/` та в навігації веб-UI **Документація**.
