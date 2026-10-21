#!/usr/bin/env bash
# Al conectar los AirPods deja A2DP (musica) como perfil por defecto, aunque
# la ultima sesion haya terminado en HFP/CVSD. Solo actua cuando aparece una
# tarjeta bluez nueva; no interfiere con Super+Shift+C durante una llamada.
set -u

PROFILE_MUSIC="a2dp-sink-sbc_xq"
LOG="$HOME/.cache/airpods-default-mode.log"

card() {
    pactl list cards short 2>/dev/null |
        awk '$2 ~ /^bluez_card\./ {print $2; exit}'
}

profile() {
    pactl -f json list cards 2>/dev/null |
        jq -r --arg c "$1" '.[] | select(.name == $c) | .active_profile' 2>/dev/null
}

ensure_music() {
    local c p
    c=$(card)
    [ -n "$c" ] || return 0
    p=$(profile "$c")
    case "$p" in
    a2dp-*) return 0 ;;
    esac
    pactl set-card-profile "$c" "$PROFILE_MUSIC" 2>/dev/null ||
        pactl set-card-profile "$c" a2dp-sink 2>/dev/null || true
    printf '%s card=%s perfil=%s -> %s\n' \
        "$(date -Is)" "$c" "$p" "$(profile "$c")" >>"$LOG"
}

ensure_music

while :; do
    # LC_ALL=C: los eventos de pactl se traducen ("Evento 'nuevo' en tarjeta")
    LC_ALL=C stdbuf -oL pactl subscribe 2>/dev/null | while read -r ev; do
        case "$ev" in
        "Event 'new' on card"*)
            sleep 1
            ensure_music
            ;;
        esac
    done
    sleep 2
done
