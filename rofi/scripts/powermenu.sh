#!/bin/bash

THEME="$HOME/.config/rofi/themes/rounded-custom.rasi"

options="Apagar\x00icon\x1fsystem-shutdown\nReiniciar\x00icon\x1fsystem-reboot\nCerrar sesión\x00icon\x1fsystem-log-out"

chosen=$(echo -e "$options" | rofi -dmenu -p "Power" -theme "$THEME")

case "$chosen" in
Apagar) systemctl poweroff ;;
Reiniciar) systemctl reboot ;;
"Cerrar sesión") loginctl terminate-user "$USER" ;;
esac
