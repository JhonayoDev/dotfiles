#!/bin/bash
# Control Center principal
# Botones de sistema arriba + buscador de apps abajo
# Super + Space

THEME="$HOME/.config/rofi/themes/control-center.rasi"
SCRIPTS="$HOME/.config/rofi/scripts/system"

chosen=$(printf "🔵  Bluetooth\n🔊  Salida de audio\n⏻   Power\n" | rofi \
    -dmenu \
    -p "  " \
    -mesg "Acciones del sistema" \
    -theme "$THEME")

[ -z "$chosen" ] && exit 0

case "$chosen" in
    *"Bluetooth"*)  "$SCRIPTS/bluetooth.sh" ;;
    *"Salida"*)     "$SCRIPTS/audio_output.sh" ;;
    *"Power"*)      "$SCRIPTS/power.sh" ;;
esac
