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
# El controlador BCM20702 no tiene el alternate setting USB (Alt6) que
# necesita el mSBC transparente; PipeWire cae siempre a CVSD (8 kHz). Con un
# dongle que si lo soporte (ej. RTL8761B) se puede usar headset-head-unit.
# Override: AIRPODS_PROFILE_CALL=headset-head-unit
PROFILE_CALL="${AIRPODS_PROFILE_CALL:-headset-head-unit-cvsd}"
LOG="$HOME/.cache/airpods-mode.log"

# Misma apariencia que la notificacion de conexion de blueman:
# app blueman + icono de audifonos + titulo "AirPods Pro"; solo cambia el cuerpo.
notify() { notify-send -a blueman -i audio-headphones "AirPods Pro" "$1" 2>/dev/null || true; }
log() { printf '%s %s\n' "$(date -Is)" "$*" >>"$LOG" 2>/dev/null || true; }

if ! command -v pactl >/dev/null; then
    notify "Error · pactl no encontrado"
    exit 1
fi

# Si la MAC cambia, cae al primer bluez_card disponible
if ! pactl list cards short 2>/dev/null | awk '{print $2}' | grep -qx "$CARD"; then
    CARD=$(pactl list cards short 2>/dev/null |
        awk '$2 ~ /^bluez_card\./ {print $2; exit}')
fi

if [ -z "${CARD:-}" ]; then
    if [ "${1:-toggle}" = "status" ]; then
        echo "AirPods no conectados (sin tarjeta bluez)"
        exit 0
    fi
    notify "No conectados · enciende/conecta los audifonos"
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

airpods_source() {
    pactl list sources short 2>/dev/null | awk '/bluez_input/ {print $2; exit}'
}

set_default_source() {
    local src="$1"
    [ -n "$src" ] && pactl set-default-source "$src" 2>/dev/null || true
}

restore_default_source() {
    # Al volver a A2DP la fuente bluez desaparece: dejar el micro interno
    case "$(pactl get-default-source 2>/dev/null)" in
    bluez_input.*)
        set_default_source "$(pactl list sources short 2>/dev/null |
            awk '/alsa_input/ {print $2; exit}')"
        ;;
    esac
}

do_call() {
    local prof
    prof=$(current_profile)
    case "$prof" in
    headset-head-unit*)
        set_default_source "$(airpods_source)"
        notify "Llamada ya activa · mic AirPods (8 kHz)"
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
                notify "Sin micrófono · revisa que el iPhone no tenga la llamada"
                log "fallo total modo llamada (perfil=$(current_profile))"
                return 1
            }
        fi
    fi

    local info src
    for _ in $(seq 10); do
        src=$(airpods_source)
        [ -n "$src" ] && break
        sleep 0.1
    done
    set_default_source "$src"
    info=$(source_info)
    log "modo llamada: $(current_profile) | $info | default=$src"
    notify "Llamada · mic AirPods (8 kHz)"
}

do_music() {
    if [ "$(current_profile)" = "$PROFILE_MUSIC" ]; then
        restore_default_source
        notify "Música · A2DP ya activo"
        return 0
    fi

    if ! profile_set "$PROFILE_MUSIC"; then
        log "fallo perfil $PROFILE_MUSIC, reintento a2dp-sink"
        if ! profile_set "a2dp-sink"; then
            reconnect
            if ! profile_set "$PROFILE_MUSIC"; then
                profile_set "a2dp-sink" || {
                    notify "Sin audio · reconecta los AirPods"
                    log "fallo total modo musica (perfil=$(current_profile))"
                    return 1
                }
            fi
        fi
    fi

    restore_default_source
    log "modo musica: $(current_profile)"
    notify "Música · A2DP estéreo"
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
    prof=$(current_profile)
    case "$prof" in
    headset-head-unit*) note="HFP CVSD 8 kHz (limite BCM20702); mic predeterminado" ;;
    a2dp-*) note="A2DP; para llamadas: Super+Shift+C (mic AirPods)" ;;
    *) note="sin perfil de audio" ;;
    esac
    printf 'card:    %s\nperfil:  %s\nfuente:  %s\ndefault: %s\nnota:    %s\n' \
        "$CARD" "$prof" "$(source_info)" "$(pactl get-default-source 2>/dev/null)" "$note"
    ;;
*)
    echo "Uso: $0 [call|music|toggle|status]" >&2
    exit 2
    ;;
esac
