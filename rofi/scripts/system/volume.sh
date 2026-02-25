#!/bin/bash

options=" Subir\n Bajar\n󰖁 Silenciar"

chosen=$(echo -e "$options" | rofi -dmenu -p "Volume" \
  -theme ~/.config/rofi/themes/rounded-custom.rasi)

case "$chosen" in
*Subir) pactl set-sink-volume @DEFAULT_SINK@ +5% ;;
*Bajar) pactl set-sink-volume @DEFAULT_SINK@ -5% ;;
*Silenciar) pactl set-sink-mute @DEFAULT_SINK@ toggle ;;
esac
