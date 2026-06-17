# Встановлення

## Встановлення в один клік

На **чистій Ubuntu 24.04** або **Raspberry Pi OS Bookworm**:

```bash
cd ~/ros2_delatometry
bash scripts/install.sh
```

Оберіть **Full one-click** — потім **версію ОС + ROS 2** (наприклад **Debian Bookworm + Jazzy**). На Raspberry Pi також оберіть **Pi 4 чи Pi 5** для налаштування GPIO/PWM.

Скрипт встановлює:

| Крок | Що |
|------|-----|
| apt | MariaDB, Python, pigpio, dphys-swapfile, інструменти збірки |
| Pi | swap 2 ГБ, UART на GPIO для HMI, SPI, PWM (Pi 4 / Pi 5) |
| ROS 2 | Обрана пара з діалогу |
| БД | `exp`, користувач `delatometry` |
| Python | venv + усі `requirements.txt` |
| colcon | Усі пакети Delatometry |
| systemd | Служби та `/etc/default/delatometry` |

Без інтерактиву:

```bash
INSTALL_NONINTERACTIVE=1 INSTALL_MODE=scratch ROS_TARGET=bookworm-jazzy bash scripts/install.sh
INSTALL_MODE=rebuild bash scripts/install.sh
```

Pi 5 без діалогу:

```bash
INSTALL_NONINTERACTIVE=1 INSTALL_MODE=scratch ROS_TARGET=bookworm-jazzy RPI_MODEL=rpi5 bash scripts/install.sh
```

Запускайте звичайним користувачем з **sudo** (не root). Після першого встановлення на Pi **перезавантажте**, якщо змінювали UART або PWM у boot config.

## Raspberry Pi (інсталятор)

| Функція | Pi 4 / Pi 3 / Zero 2 W | Pi 5 |
|---------|------------------------|------|
| PWM нагрівача | `pigpiod` | `lgpio` |
| `pigpiod` | Увімкнено | Вимкнено і masked |
| Overlay PWM | — | `dtoverlay=pwm` |
| Swap | 2 ГБ | 2 ГБ |
| UART HMI | GPIO 14/15 | Те саме |
| Графіки запусків | `/var/lib/delatometry/run_charts` | Те саме |

У `/etc/default/delatometry`: `DELATOMETRY_RPI_MODEL`, `DELATOMETRY_PWM_BACKEND`, `DELATOMETRY_HMI_PORT`, `DELATOMETRY_WEBUI_RUN_CHARTS_DIR`.

## Вимоги

| Компонент | Примітки |
|-----------|----------|
| ОС | Ubuntu 24.04, Debian 12 Bookworm (Pi OS) |
| ROS 2 | Jazzy, Humble — `/opt/ros/<distro>/setup.bash` |
| БД | MariaDB |
| Python | venv `~/venvs/ros2_delatometry_webui` |

```bash
ROS_TARGET=bookworm-jazzy INSTALL_MODE=scratch bash scripts/install.sh
```

## Змінні інсталятора

| Змінна | За замовч. | Призначення |
|--------|------------|-------------|
| `RPI_MODEL` | діалог | `rpi4` або `rpi5` |
| `SWAP_SIZE_MB` | `2048` | Розмір swap на Pi |
| `ADD_PI5_PWM_OVERLAY` | `1` | Додати `dtoverlay=pwm` на Pi 5 |
| `DELATOMETRY_WEBUI_RUN_CHARTS_DIR` | `/var/lib/delatometry/run_charts` | PNG графіків запусків |

## Після встановлення

| Ресурс | Розташування |
|--------|----------------|
| Env | `/etc/default/delatometry` |
| Веб-UI | `http://<ip>/` |
| Графіки | `/var/lib/delatometry/run_charts` |
| Статус | `scripts/systemd/status.sh` |
| Логи | `scripts/systemd/logs.sh all` |

## Ручна збірка

```bash
source /opt/ros/jazzy/setup.bash
cd ~/ros2_delatometry
colcon build --symlink-install
source install/setup.bash
```

## Оновлення на Pi

```bash
cd ~/ros2_delatometry
colcon build --packages-select webui core
scripts/systemd/install_services.sh
sudo systemctl restart delatometry-core delatometry-webui
```

Документація: `share/webui/docs/`, URL `/docs`.
