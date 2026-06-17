# Встановлення

## Встановлення в один клік

На **чистій Ubuntu 24.04** (зокрема Raspberry Pi):

```bash
cd ~/ros2_delatometry
bash scripts/install.sh
```

Оберіть **Full one-click** — потім оберіть **версію ОС + ROS 2** (наприклад **Debian Bookworm + Jazzy** для тестової Pi). Далі: apt, ROS, MariaDB, venv, colcon, systemd.

Без інтерактиву:

```bash
INSTALL_MODE=scratch bash scripts/install.sh
INSTALL_MODE=rebuild bash scripts/install.sh
```

Запускайте звичайним користувачем з **sudo** (не root).

## Вимоги

| Компонент | Примітки |
|-----------|----------|
| ОС | Ubuntu 24.04, Debian 12 Bookworm (Pi OS) — відповідна пара в діалозі |
| ROS 2 | Jazzy, Humble, Rolling — `/opt/ros/<distro>/setup.bash` |
| БД | MariaDB (встановлюється скриптом) |
| Python | venv `~/venvs/ros2_delatometry_webui` |

**Bookworm:** оберіть **Debian 12 Bookworm + ROS 2 Jazzy** (автовибір при виявленні `bookworm`).

```bash
ROS_TARGET=bookworm-jazzy INSTALL_MODE=scratch bash scripts/install.sh
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
