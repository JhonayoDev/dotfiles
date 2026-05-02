#!/bin/bash
# Selector de salida de audio
THEME="$HOME/.config/rofi/themes/submenu.rasi"

# Obtener sink activo (Ubuntu/PipeWire en español)
current=$(pactl info | grep "Destino por defecto" | awk '{print $NF}')

# Construir lista
menu=""
while read -r line; do
  if [[ $line == *"Nombre:"* ]]; then
    id=$(echo "$line" | awk '{print $2}')
  fi
  if [[ $line == *"Descripción:"* ]]; then
    desc=$(echo "$line" | cut -d':' -f2- | sed 's/^ //')
    if [ "$id" = "$current" ]; then
      menu="${menu}✔ $desc|$id\n"
    else
      menu="${menu}  $desc|$id\n"
    fi
  fi
done < <(pactl list sinks)

[ -z "$menu" ] && notify-send "Audio" "No se encontraron dispositivos" && exit 1

chosen=$(echo -e "$menu" | cut -d'|' -f1 | rofi -dmenu -p "🔊 Salida de audio" -theme "$THEME")
[ -z "$chosen" ] && exit 0

selected=$(echo -e "$menu" | grep -F "$chosen" | cut -d'|' -f2)
pactl set-default-sink "$selected"
notify-send "Audio" "Salida cambiada a: $(echo "$chosen" | sed 's/^[✔ ]*//')" -t 2000
