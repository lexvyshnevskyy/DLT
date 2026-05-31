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

UART port and baud rate are set in HMI params / `/etc/default/delatometry`. The **Configuration** page in webui can show UART diagnostics.

## When to use which UI

| Interface | Best for |
|-----------|----------|
| Web UI | Program editing, charts, export, system admin |
| Nextion HMI | Bench operation without a laptop |

Both can be used together; core serializes program commands under locks.
