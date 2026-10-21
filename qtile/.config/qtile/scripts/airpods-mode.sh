#!/usr/bin/env bash
# airpods-mode.sh [call|music|toggle|status]
#
# Cambia el perfil de los AirPods entre A2DP (musica estereo) y HFP
# (microfono + audio mono) para llamadas en Discord/Teams/Zoom.
#
# El autoswitch de WirePlumber esta desactivado a proposito: al activarse
# mientras suena A2DP puede dejar el transporte en mal estado (SEP in bad
# state) y el audio "suena" sin oirse hasta reconectar. Este cambio manual
# pausa primero y verifica que el perfil quedo aplicado.
set -u

CARD="${AIRPODS_CARD:-bluez_card.90_62_3F_5D_0E_1A}"
PROFILE_MUSIC="a2dp-sink-sbc_xq"
# Este combo AirPods Pro + BCM20702 solo negocia CVSD (8 kHz); pedir
# headset-head-unit (mSBC/16 kHz) termina igual en cvsd. Se puede forzar con
# AIRPODS_PROFILE_CALL=headset-head-unit si en el futuro negocian mSBC.
PROFILE_CALL="${AIRPODS_PROFILE_CALL:-headset-head-unit-cvsd}"
LOG="$HOME/.cache/airpods-mode.log"

notify() { notify-send -a AirPods "$1" "${2:-}" 2>/dev/null || true; }
log() { printf '%s %s\n' "$(date -Is)" "$*" >>"$LOG" 2>/dev/null || true; }

if ! command -v pactl >/dev/null; then
    notify "pactl no encontrado"
    exit 1
fi

# Si la MAC cambia, cae al primer bluez_card disponible
if ! pactl list cards short 2>/dev/null | awk '{print $2}' | grep -qx "$CARD"; then
    CARD=$(pactl -f json list cards 2>/dev/null |
        jq -r '.[] | select(.name | startswith("bluez_card.")) | .name' 2>/dev/null |
        head -n1)
fi

if [ -z "${CARD:-}" ]; then
    notify "AirPods no conectados" "Enciende/conecta los audifonos"
    exit 1
fi

MAC=$(printf '%s' "${CARD#bluez_card.}" | tr '_' ':')

current_profile() {
    pactl -f json list cards 2>/dev/null |
        jq -r --arg c "$CARD" '.[] | select(.name == $c) | .active_profile' 2>/dev/null
}

has_source() {
    pactl list sources short 2>/dev/null | grep -q '^[0-9].*bluez_source'
}

profile_set() {
    local want="$1"
    pactl set-card-profile "$CARD" "$want" 2>/dev/null || return 1
    for _ in $(seq 20); do
        [ "$(current_profile)" = "$want" ] && return 0
        sleep 0.1
    done
    return 1
}

reconnect() {
    command -v bluetoothctl >/dev/null || return 1
    bluetoothctl disconnect "$MAC" >/dev/null 2>&1 || true
    sleep 1
    bluetoothctl connect "$MAC" >/dev/null 2>&1 || true
    sleep 2
}

source_info() {
    # pactl json falla con nombres UTF-8 invalidos de PipeWire; usar texto plano
    pactl list sources short 2>/dev/null |
        awk '/bluez_input/ {printf "%s  %s %s", $4, $5, $6; exit}'
}

do_call() {
    local prof
    prof=$(current_profile)
    case "$prof" in
    headset-head-unit | headset-head-unit-cvsd)
        notify "Modo llamada ya activo" "$prof"
        return 0
        ;;
    esac

    # Pausar antes de tocar el transporte A2DP reduce el riesgo de SEP in bad state
    playerctl -a pause >/dev/null 2>&1 || true

    if ! profile_set "$PROFILE_CALL"; then
        # Sin reconectar (cortaba el audio): si el perfil elegido no aplica,
        # caer a CVSD directo y solo reconectar como ultimo recurso.
        log "fallo perfil $PROFILE_CALL, probando cvsd sin reconectar"
        if ! profile_set "headset-head-unit-cvsd"; then
            log "fallo cvsd, reconectando"
            reconnect
            profile_set "headset-head-unit-cvsd" || {
                notify "No pude activar el microfono" "Revisa que no este conectado al iPhone"
                log "fallo total modo llamada (perfil=$(current_profile))"
                return 1
            }
        fi
    fi

    local info
    info=$(source_info)
    log "modo llamada: $(current_profile) | $info"
    notify "Modo llamada: mic activo" "$info"
}

do_music() {
    if [ "$(current_profile)" = "$PROFILE_MUSIC" ]; then
        notify "Modo musica ya activo" "$PROFILE_MUSIC"
        return 0
    fi

    if ! profile_set "$PROFILE_MUSIC"; then
        log "fallo perfil $PROFILE_MUSIC, reintento a2dp-sink"
        if ! profile_set "a2dp-sink"; then
            reconnect
            if ! profile_set "$PROFILE_MUSIC"; then
                profile_set "a2dp-sink" || {
                    notify "No pude volver a A2DP" "Reconecta los AirPods"
                    log "fallo total modo musica (perfil=$(current_profile))"
                    return 1
                }
            fi
        fi
    fi

    log "modo musica: $(current_profile)"
    notify "Modo musica: A2DP" "$(current_profile)"
}

case "${1:-toggle}" in
call) do_call ;;
music) do_music ;;
toggle)
    case "$(current_profile)" in
    headset-head-unit*) do_music ;;
    *) do_call ;;
    esac
    ;;
status)
    printf 'card:    %s\nperfil:  %s\nfuente:  %s\n' \
        "$CARD" "$(current_profile)" "$(source_info)"
    ;;
*)
    echo "Uso: $0 [call|music|toggle|status]" >&2
    exit 2
    ;;
esac
