#!/bin/bash
# Toggle trackpad bcm5974 — fix 2026-08-23: usa nombre en vez de ID 11 (cambia con Logitech/dock)
# Solo F4 sin Fn (XF86LaunchB, fnmode 2) toggleará; Fn+F4 seguirá siendo F4 puro para apps
DEVICE="bcm5974"
ID=$(xinput list --id-only "$DEVICE" 2>/dev/null)

if [ -z "$ID" ]; then
    notify-send "Trackpad" "No encontrado ($DEVICE)" -t 2000
    exit 1
fi

STATUS=$(xinput list-props "$ID" | awk '/Device Enabled/ {print $4}')

if [ "$STATUS" = "1" ]; then
    xinput disable "$ID"
    notify-send "Trackpad" "Desactivado" -t 2000
else
    xinput enable "$ID"
    notify-send "Trackpad" "Activado" -t 2000
fi

