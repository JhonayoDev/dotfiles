#!/bin/bash
# Menú de energía

SCRIPTS="$HOME/.config/rofi/scripts"
THEME="$HOME/.config/rofi/themes/power-menu.rasi"

options="Back\0icon\x1fgo-previous-symbolic
Apagar\0icon\x1fsystem-shutdown-symbolic
Reiniciar\0icon\x1fsystem-reboot-symbolic
Cerrar sesión\0icon\x1fsystem-log-out-symbolic"

chosen=$(
  echo -e "$options" | rofi \
    -dmenu \
    -i \
    -p "󰐥 Power Menu" \
    -theme "$THEME"
)

[ -z "$chosen" ] && exit 0

case "$chosen" in
*"Back"*) "$SCRIPTS/control_center.sh" ;;
*"Apagar"*) systemctl poweroff ;;
*"Reiniciar"*) systemctl reboot ;;
*"Cerrar sesión"*) loginctl terminate-user "$USER" ;;
esac
