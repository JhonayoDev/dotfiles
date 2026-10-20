#!/bin/bash
# Volumen por aplicación (PipeWire) con rofi.
# Lista los streams de reproducción activos y permite subir/bajar, fijar % o mutear.
THEME="$HOME/.config/rofi/themes/submenu.rasi"

json=$(pactl -f json list sink-inputs 2>/dev/null)
if [ -z "$json" ] || [ "$json" = "[]" ]; then
    notify-send "Volumen por app" "No hay reproducciones activas" -t 2000
    exit 0
fi

menu=$(jq -r '
    .[] |
    [ .index,
      (.properties["application.name"] // .properties["media.name"] // "app"),
      ((.volume | to_entries | .[0].value.value_percent) // "?"),
      ((.mute | tostring))
    ] | @tsv' <<<"$json" | while IFS=$'\t' read -r idx name vol mute; do
        icon="🔊"
        [ "$mute" = "true" ] && icon="🔇"
        printf '%s %s — %s|%s\n' "$icon" "$name" "$vol" "$idx"
    done)

chosen=$(echo "$menu" | rofi -dmenu -i -p "🎚 Volumen por app" -theme "$THEME")
[ -z "$chosen" ] && exit 0
idx="${chosen##*|}"
label="${chosen%|*}"

action=$(printf 'Subir 5%%\nBajar 5%%\nFijar…\nSilenciar/Activar' \
    | rofi -dmenu -i -p "$label" -theme "$THEME")
[ -z "$action" ] && exit 0

case "$action" in
    "Subir 5%")  pactl set-sink-input-volume "$idx" +5% ;;
    "Bajar 5%")  pactl set-sink-input-volume "$idx" -5% ;;
    "Silenciar/Activar") pactl set-sink-input-mute "$idx" toggle ;;
    "Fijar…")
        current=$(pactl -f json list sink-inputs | jq -r --argjson i "$idx" \
            '.[] | select(.index == $i) | .volume | to_entries[0].value.value_percent' \
            | tr -d '%')
        val=$(rofi -dmenu -i -p "Volumen % (0-150)" -theme "$THEME" -filter "$current")
        [ -z "$val" ] && exit 0
        [[ "$val" =~ ^[0-9]+$ ]] || { notify-send "Volumen por app" "Valor inválido" -t 2000; exit 1; }
        [ "$val" -gt 150 ] && val=150
        pactl set-sink-input-volume "$idx" "${val}%"
        ;;
    *) exit 0 ;;
esac

# volver a abrir para seguir ajustando
exec "$0"
