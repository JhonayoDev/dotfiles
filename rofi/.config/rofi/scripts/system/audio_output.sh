#!/bin/bash
# Selector de salida de audio
# Muestra los dispositivos disponibles y permite cambiar el activo

THEME="$HOME/.config/rofi/themes/submenu.rasi"

# Obtener sink activo
current=$(pactl info | grep "Default Sink" | awk '{print $3}')

# Construir lista: descripción visible | id real
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
            menu="${menu}  $desc|$id\n"
        fi
    fi
done < <(pactl list sinks)

[ -z "$menu" ] && notify-send "Audio" "No se encontraron dispositivos" && exit 1

chosen=$(echo -e "$menu" | cut -d'|' -f1 | rofi -dmenu -p "🔊 Salida de audio" -theme "$THEME")
[ -z "$chosen" ] && exit 0

# Obtener ID real del dispositivo seleccionado
selected=$(echo -e "$menu" | grep -F "$chosen" | cut -d'|' -f2)
pactl set-default-sink "$selected"
notify-send "Audio" "Salida cambiada a: $(echo "$chosen" | sed 's/^[✔ ]*//')" -t 2000
