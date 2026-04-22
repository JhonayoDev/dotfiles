#!/bin/bash
# Toggle trackpad bcm5974
STATUS=$(xinput list-props 7 | grep "Device Enabled" | awk '{print $4}')

if [ "$STATUS" = "1" ]; then
    xinput disable 7
    notify-send "Trackpad" "Desactivado" -t 2000
else
    xinput enable 7
    notify-send "Trackpad" "Activado" -t 2000
fi

