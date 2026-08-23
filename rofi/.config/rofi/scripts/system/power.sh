#!/bin/bash
# Menú de energía

SCRIPTS="$HOME/.config/rofi/scripts/system"
THEME="$HOME/.config/rofi/themes/power-menu.rasi"

options="Back\0icon\x1fgo-previous-symbolic
Bloquear\0icon\x1fsystem-lock-screen-symbolic
Suspender ahora\0icon\x1fmedia-playback-pause-symbolic
Apagar\0icon\x1fsystem-shutdown-symbolic
Reiniciar\0icon\x1fsystem-reboot-symbolic
Cerrar sesión\0icon\x1fsystem-log-out-symbolic"

chosen=$(echo -e "$options" | rofi \
  -dmenu \
  -i \
  -p "󰐥 Power Menu" \
  -theme "$THEME")

[ -z "$chosen" ] && exit 0

case "$chosen" in
*"Back"*) "$HOME/.config/rofi/scripts/control_center.sh" ;;
*"Bloquear"*) "$HOME/.config/qtile/scripts/lock.sh" ;;
*"Suspender ahora"*)
    # Ubuntu GNOME-like: xss-lock --transfer-sleep-lock bloquea antes de suspend
    # Al despertar, DPMS y monitores se restauran (ver autostart y monitors.sh hotplug)
    systemctl suspend
    ;;
*"Apagar"*) systemctl poweroff ;;
*"Reiniciar"*) systemctl reboot ;;
*"Cerrar sesión"*) qtile cmd-obj -o cmd -f shutdown ;;
esac
