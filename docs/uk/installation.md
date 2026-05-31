# Встановлення

## Вимоги

| Компонент | Примітки |
|-----------|----------|
| ОС | Ubuntu / Debian 22.04+, Raspberry Pi OS |
| ROS 2 | **Jazzy** (`/opt/ros/jazzy/setup.bash`) |
| БД | MariaDB |
| Python | 3.10+; venv для webui |
| Апаратура | LTM2985 UART; опційно measure_device / ADS1256 |

## Рекомендовано: `scripts/install.sh`

```bash
cd ~/ros2_delatometry
bash scripts/install.sh
```

Меню:

1. **Повне встановлення** — apt, MariaDB, venv, pip, colcon, systemd, sudoers для webui.
2. **Перезбірка** — оновлення збірки та перезапуск служб.

Без інтерактиву:

```bash
INSTALL_MODE=scratch bash scripts/install.sh
INSTALL_MODE=rebuild bash scripts/install.sh
```

## Після встановлення

| Ресурс | Розташування |
|--------|----------------|
| Env | `/etc/default/delatometry` |
| Веб-UI | `http://<ip>/` |
| Статус служб | `scripts/systemd/status.sh` |
| Логи | `scripts/systemd/logs.sh all` |

## Ручна збірка

```bash
source /opt/ros/jazzy/setup.bash
cd ~/ros2_delatometry
colcon build --symlink-install
source install/setup.bash
```

Один пакет:

```bash
colcon build --packages-select core webui database
```

## Оновлення документації на Pi

```bash
cd ~/ros2_delatometry
colcon build --packages-select webui
pip install -r src/webui/requirements.txt
sudo systemctl restart delatometry-webui
```

Документація встановлюється в `share/webui/docs/` і доступна за `/docs`.
