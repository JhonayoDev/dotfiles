#!/bin/bash
STEP=5
MAX=$(brightnessctl m)
CURRENT=$(brightnessctl g)
# Redondear correctamente
PCT=$(( (CURRENT * 100 + MAX / 2) / MAX ))

if [ "$1" = "up" ]; then
    NEW_PCT=$(( (PCT / STEP + 1) * STEP ))
    [ $NEW_PCT -gt 100 ] && NEW_PCT=100
elif [ "$1" = "down" ]; then
    NEW_PCT=$(( (PCT / STEP) * STEP - STEP ))
    [ $NEW_PCT -lt 0 ] && NEW_PCT=0
fi

brightnessctl s "${NEW_PCT}%"
notify-send --replace-id=3000 -t 1500 "Brillo" "${NEW_PCT}%"
