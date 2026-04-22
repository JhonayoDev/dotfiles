#!/bin/bash
# Menú de energía

THEME="$HOME/.config/rofi/themes/submenu.rasi"

options="⏻  Apagar\n↺  Reiniciar\n⇥  Cerrar sesión"

chosen=$(echo -e "$options" | rofi -dmenu -p "Power" -theme "$THEME")
[ -z "$chosen" ] && exit 0

case "$chosen" in
    "⏻  Apagar")        systemctl poweroff ;;
    "↺  Reiniciar")     systemctl reboot ;;
    "⇥  Cerrar sesión") loginctl terminate-user "$USER" ;;
esac
