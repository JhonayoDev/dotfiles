#!/usr/bin/env bash
# Control de volumen del sink por defecto.
# Uso: volume.sh up|down [paso]   (paso por defecto 2)
#      volume.sh mute
set -u

sink=$(pactl get-default-sink 2>/dev/null) || exit 1
step="${2:-2}"

notify() {
    notify-send --replace-id=1000 --expire-time=1200 "$1" "$2"
}

case "${1:-}" in
    up)   pactl set-sink-volume "$sink" "+${step}%" ;;
    down) pactl set-sink-volume "$sink" "-${step}%" ;;
    mute) pactl set-sink-mute "$sink" toggle
          if pactl get-sink-mute "$sink" | grep -qiE 'sí|yes'; then
              notify "󰝟 Volumen" "Silenciado"
          else
              notify "󰕾 Volumen" "$(pactl get-sink-volume "$sink" | grep -oP '\d+(?=%)' | head -1)%"
          fi
          exit 0 ;;
    *)    echo "uso: $0 up|down [paso] | mute" >&2; exit 2 ;;
esac

vol=$(pactl get-sink-volume "$sink" | grep -oP '\d+(?=%)' | head -1)
if [ "${vol:-0}" -gt 100 ]; then
    pactl set-sink-volume "$sink" 100%
    vol=100
fi
notify "󰕾 Volumen" "${vol}%"
