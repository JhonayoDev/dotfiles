#!/bin/bash
# brightness.sh — brillo de pantalla (intel_backlight)
# Revisado 2026-08-23: explícito --device, manejo de bordes, sin ambigüedad con leds
set -e
DEVICE="intel_backlight"
STEP=5

# Obtiene max/actual del device correcto (evita que leds::capslock sea el default)
if ! MAX=$(brightnessctl --device "$DEVICE" max 2>/dev/null); then
    MAX=$(brightnessctl --class backlight max 2>/dev/null || echo 100)
fi
if ! CURRENT=$(brightnessctl --device "$DEVICE" get 2>/dev/null); then
    CURRENT=$(brightnessctl --class backlight get 2>/dev/null || echo 0)
fi

# evita división por cero
[ "$MAX" -eq 0 ] && MAX=1
PCT=$(( (CURRENT * 100 + MAX / 2) / MAX ))

case "$1" in
    up)
        NEW_PCT=$(( (PCT / STEP + 1) * STEP ))
        [ "$NEW_PCT" -gt 100 ] && NEW_PCT=100
        ;;
    down)
        # si PCT está justo en múltiplo, baja un STEP; si está entre, alinea hacia abajo y baja
        NEW_PCT=$(( (PCT / STEP) * STEP - STEP ))
        # si PCT no era múltiplo exacto, el cálculo anterior puede bajar 2 steps; corrige al múltiplo inferior más cercano
        if [ $((PCT % STEP)) -ne 0 ]; then
            NEW_PCT=$(( (PCT / STEP) * STEP ))
        fi
        [ "$NEW_PCT" -lt 5 ] && NEW_PCT=5   # mínimo 5% para no quedar pantalla negra por accidente
        [ "$NEW_PCT" -lt 0 ] && NEW_PCT=0
        ;;
    *)
        echo "Uso: $0 up|down" >&2
        exit 1
        ;;
esac

brightnessctl --device "$DEVICE" set "${NEW_PCT}%" -q
notify-send --replace-id=3000 --expire-time=1500 "󰃠 Brillo" "${NEW_PCT}%"
