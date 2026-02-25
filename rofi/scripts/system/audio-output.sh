#!/bin/bash

theme="$HOME/.config/rofi/themes/rounded-custom.rasi"

# Obtener sink activo
current=$(pactl info | grep "Default Sink" | awk '{print $3}')

# Construir lista nombre bonito → ID real
menu=""

while read -r line; do
  if [[ $line == Name:* ]]; then
    id=$(echo "$line" | awk '{print $2}')
  fi
  if [[ $line == Description:* ]]; then
    desc=$(echo "$line" | cut -d':' -f2- | sed 's/^ //')

    if [ "$id" = "$current" ]; then
      menu="${menu}✔ $desc|$id\n"
    else
      menu="${menu}$desc|$id\n"
    fi
  fi
done < <(pactl list sinks)

chosen=$(echo -e "$menu" | cut -d'|' -f1 | rofi -dmenu -p "Audio Output" -theme "$theme")

[ -z "$chosen" ] && exit 1

# Obtener ID real
selected=$(echo -e "$menu" | grep "$chosen" | cut -d'|' -f2)

pactl set-default-sink "$selected"
