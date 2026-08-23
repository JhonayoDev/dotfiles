#!/bin/bash
# kbd-backlight.sh — backlight del teclado MacBook (smc::kbd_backlight)
# Uso: kbd-backlight.sh up|down|toggle
# Solo teclas nativas con símbolo: XF86KbdBrightnessUp/Down/LightOnOff
# Revisado 2026-08-23: sin auto, sin depender de F5/F6, con toggle y persistencia
set -e

DEVICE="smc::kbd_backlight"
STEP_PCT=6          # ~6% ≈ 16 niveles (16*16=256 ≈ 255)
TMP_LAST="/tmp/kbd_backlight_last"

# Si el device no existe (PC sin teclado retroiluminado), salir silencioso
if ! brightnessctl --device "$DEVICE" max >/dev/null 2>&1; then
    # fallback a clase leds por si el nombre cambia
    DEVICE=$(brightnessctl --class leds list 2>/dev/null | grep -i "kbd_backlight" | head -n1 | cut -d"'" -f2 || echo "$DEVICE")
    if ! brightnessctl --device "$DEVICE" max >/dev/null 2>&1; then
        notify-send --replace-id=3001 --expire-time=1500 "⌨ Backlight" "No disponible en este equipo"
        exit 0
    fi
fi

MAX=$(brightnessctl --device "$DEVICE" max)
CURRENT=$(brightnessctl --device "$DEVICE" get)
[ "$MAX" -eq 0 ] && MAX=255

# porcentaje actual redondeado
PCT=$(( (CURRENT * 100 + MAX / 2) / MAX ))

case "$1" in
    up)
        # sube al siguiente múltiplo de STEP_PCT
        NEW_PCT=$(( (PCT / STEP_PCT + 1) * STEP_PCT ))
        [ "$NEW_PCT" -gt 100 ] && NEW_PCT=100
        ;;
    down)
        if [ "$PCT" -eq 0 ]; then
            NEW_PCT=0
        else
            # baja un step, alineando a múltiplo inferior
            if [ $((PCT % STEP_PCT)) -eq 0 ]; then
                NEW_PCT=$(( PCT - STEP_PCT ))
            else
                NEW_PCT=$(( (PCT / STEP_PCT) * STEP_PCT ))
            fi
            [ "$NEW_PCT" -lt 0 ] && NEW_PCT=0
        fi
        ;;
    toggle)
        if [ "$CURRENT" -gt 0 ]; then
            echo "$PCT" > "$TMP_LAST"
            NEW_PCT=0
        else
            if [ -f "$TMP_LAST" ]; then
                LAST=$(cat "$TMP_LAST" 2>/dev/null || echo 50)
            else
                LAST=50
            fi
            # asegura múltiplo de STEP
            NEW_PCT=$(( (LAST / STEP_PCT) * STEP_PCT ))
            [ "$NEW_PCT" -eq 0 ] && NEW_PCT=50
            [ "$NEW_PCT" -gt 100 ] && NEW_PCT=50
        fi
        ;;
    *)
        echo "Uso: $0 up|down|toggle" >&2
        exit 1
        ;;
esac

brightnessctl --device "$DEVICE" set "${NEW_PCT}%" -q

# guarda último nivel no-cero para toggle
if [ "$NEW_PCT" -gt 0 ]; then
    echo "$NEW_PCT" > "$TMP_LAST"
fi

# icono según nivel
if [ "$NEW_PCT" -eq 0 ]; then
    ICON="󰌌"
elif [ "$NEW_PCT" -lt 30 ]; then
    ICON="󰌐"
elif [ "$NEW_PCT" -lt 70 ]; then
    ICON="󰌑"
else
    ICON="󰌒"
fi

notify-send --replace-id=3001 --expire-time=1500 "$ICON Backlight Teclado" "${NEW_PCT}%"
