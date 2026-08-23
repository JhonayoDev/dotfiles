#!/bin/bash
# config.sh — ajustes rápidos de pantalla y suspensión (pasos cíclicos)
# Accesible desde Control Center → Config

THEME="$HOME/.config/rofi/themes/power-menu.rasi"
SCRIPTS="$HOME/.config/rofi/scripts/system"
CONF="$HOME/.config/qtile/power.conf"
if [ -f "$CONF" ]; then source "$CONF" 2>/dev/null; fi
SCREEN_SEC=${SCREEN_SEC:-300}
SUSPEND_SEC=${SUSPEND_SEC:-900}
SUSPEND_TYPE=${SUSPEND_TYPE:-suspend}
fmt() { if [ "$1" -eq 0 ] 2>/dev/null; then echo "Nunca"; else echo "$(( $1 / 60 )) min"; fi; }
SCREEN_FMT=$(fmt "$SCREEN_SEC")
if [ "${SUSPEND_TYPE}" = "nothing" ] || [ "$SUSPEND_SEC" -eq 0 ] 2>/dev/null; then SUSPEND_FMT="Nunca"; else SUSPEND_FMT=$(fmt "$SUSPEND_SEC"); fi

options="Back\0icon\x1fgo-previous-symbolic
Pantalla  ($SCREEN_FMT)\0icon\x1fvideo-display-symbolic
Suspensión ($SUSPEND_FMT)\0icon\x1fsystem-suspend-symbolic
Monitores\0icon\x1fvideo-display-symbolic
Teclado\0icon\x1finput-keyboard-symbolic"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "󰒓 Config" -theme "$THEME")
[ -z "$chosen" ] && exit 0

case "$chosen" in
    *"Back"*) "$HOME/.config/rofi/scripts/control_center.sh" ;;
    *"Pantalla"*) CALLER=config "$SCRIPTS/power-screen.sh" ;;
    *"Suspensión"*) CALLER=config "$SCRIPTS/power-suspend.sh" ;;
    *"Monitores"*) "$HOME/.config/qtile/scripts/monitors.sh" && notify-send "🖥 Monitores" "Reconfigurados" -t 1500 ;;
    *"Teclado"*) "$SCRIPTS/../kb_layout.sh" 2>/dev/null || notify-send "⌨ Teclado" "US layout" -t 1500 ;;
esac
