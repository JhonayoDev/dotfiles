#!/bin/bash
# Volumen por aplicación (PipeWire).
# rofi elige la app; zenity muestra un slider (arrastrar o flechas, 1%).
# Sin zenity: lista numérica 0-100 en rofi. Esc cierra; al aplicar vuelve
# a la lista para ajustar otra app.
THEME="$HOME/.config/rofi/themes/submenu.rasi"

set_vol() {
    pactl set-sink-input-volume "$1" "$2%" 2>/dev/null
}

get_vol() {
    pactl -f json list sink-inputs 2>/dev/null | jq -r --argjson i "$1" \
        '.[] | select(.index == $i) | .volume | to_entries[0].value.value_percent' \
        | tr -d '%'
}

while :; do
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

    chosen=$(echo "$menu" | rofi -dmenu -i -p "🎚 Volumen por app" \
        -mesg "Alt+M: silenciar/activar la app seleccionada" \
        -kb-custom-1 "Alt+m" -theme "$THEME")
    rc=$?
    # Escape / cerrar
    [ "$rc" -eq 1 ] && exit 0
    idx="${chosen##*|}"
    label="${chosen%|*}"
    [ -z "$idx" ] && exit 0

    # Alt+M: mute toggle sin abrir el slider
    if [ "$rc" -eq 10 ]; then
        pactl set-sink-input-mute "$idx" toggle
        continue
    fi

    cur=$(get_vol "$idx")
    [ -z "$cur" ] && cur=50

    if command -v zenity >/dev/null 2>&1; then
        val=$(zenity --scale --title="Volumen por app" --text="$label" \
            --min-value=0 --max-value=100 --value="$cur" --step=1 2>/dev/null)
        [ -n "$val" ] && set_vol "$idx" "$val"
    else
        val=$(seq 0 100 | sed 's/$/%/' \
            | rofi -dmenu -i -p "$label" -theme "$THEME" -select "${cur}%")
        [ -n "$val" ] && set_vol "$idx" "${val%\%}"
    fi
done
