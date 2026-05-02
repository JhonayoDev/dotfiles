#!/bin/bash
THEME="$HOME/.config/rofi/themes/control-center.rasi"
SCRIPTS="$HOME/.config/rofi/scripts/system"

options="Bluetooth\0icon\x1fbluetooth-symbolic
Audio\0icon\x1faudio-volume-high-symbolic
Power\0icon\x1fsystem-shutdown-symbolic"

chosen=$(
  echo -e "$options" | rofi \
    -dmenu \
    -i \
    -p "Control Center" \
    -theme "$THEME"
)

case "$chosen" in
*"Bluetooth"*) "$SCRIPTS/bluetooth.sh" ;;
*"Audio"*) "$SCRIPTS/audio_output.sh" ;;
*"Power"*) "$SCRIPTS/power.sh" ;;
esac
