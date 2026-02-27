#!/usr/bin/env bash

THEME="$HOME/.config/rofi/themes/rounded-custom.rasi"

layout='
listview {
    lines: 2;
    columns: 3;
    spacing: 10px;
}
element {
    orientation: vertical;
    children: [ element-icon, element-text ];
    padding: 20px 10px;
    spacing: 8px;
    border-radius: 18px;
}
element-icon {
    size: 40px;
    horizontal-align: 0.5 ;
    vertical-align: 0.5;
}
element-text {
    horizontal-align: 0.5;
    vertical-align: 0.5;
    expand: false;
}
'

options="Bluetooth\0icon\x1fbluetooth\nVolume\0icon\x1faudio-volume-medium\nAudio\0icon\x1faudio-volume-high\nPower\0icon\x1fsystem-shutdown"

chosen=$(echo -e "$options" | rofi \
  -dmenu \
  -i \
  -p "Control Center" \
  -theme "$THEME" \
  -theme-str "$layout")

case "$chosen" in
Bluetooth) ~/.config/rofi/scripts/system/bluetooth.sh ;;
Audio) ~/.config/rofi/scripts/system/audio-output.sh ;;
Volume) ~/.config/rofi/scripts/system/volume.sh ;;
Power) ~/.config/rofi/scripts/powermenu.sh ;;
esac
