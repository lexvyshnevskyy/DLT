# HMI (Nextion)

Package **`hmi`** drives a **Nextion** display over **RS-232 UART**. It is separate from the browser Web UI.

## Role

- Show program / temperature status
- Start and stop programs via physical UI
- Stay in sync with **`/core/experiment/status`** (same as webui)

HMI does **not** own program timing; commands go to core like the web UI.

## Service

`delatometry-hmi.service`

## Sync behavior

On connect and status updates, HMI reflects whether a program is running so buttons and labels match core (fixes stale “running” after web UI restart).

## Configuration

UART port and baud rate: **`DELATOMETRY_HMI_PORT`** and **`DELATOMETRY_HMI_BAUDRATE`** in `/etc/default/delatometry`.

The one-click installer on Raspberry Pi:

- Enables serial hardware on **GPIO 14/15** (`raspi-config`, `enable_uart=1`)
- Disables login shell on the UART
- Sets `DELATOMETRY_HMI_PORT` to the primary header device (often `/dev/serial0` or `/dev/ttyAMA10` on Pi 5)

Default baud: **115200**. Reboot after first install if HMI cannot open the port.

The **Dashboard** and **Configuration** pages show UART port status.

## When to use which UI

| Interface | Best for |
|-----------|----------|
| Web UI | Program editing, charts, export, system admin |
| Nextion HMI | Bench operation without a laptop |

Both can be used together; core serializes program commands under locks.
