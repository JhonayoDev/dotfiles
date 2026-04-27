#!/bin/bash
# Toggle trackpad bcm5974
STATUS=$(xinput list-props 11 | grep "Device Enabled" | awk '{print $4}')

if [ "$STATUS" = "1" ]; then
    xinput disable 11
    notify-send "Trackpad" "Desactivado" -t 2000
else
    xinput enable 11
    notify-send "Trackpad" "Activado" -t 2000
fi

