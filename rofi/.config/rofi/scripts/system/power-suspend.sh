#!/bin/bash
# power-suspend.sh — ajusta suspensión (pasos cíclicos por minutos + Nunca)
# Default 15m, muestra estado actual, aplica via power-timeouts.sh suspend <sec>
# Suspender funciona como Ubuntu GNOME: systemctl suspend + xss-lock bloquea antes, DPMS/monitors se restauran al despertar

POWER_TIMEOUTS="$HOME/.config/qtile/scripts/power-timeouts.sh"
THEME="$HOME/.config/rofi/themes/power-menu.rasi"
[ ! -x "$POWER_TIMEOUTS" ] && POWER_TIMEOUTS="$HOME/dotfiles/qtile/.config/qtile/scripts/power-timeouts.sh"
[ ! -x "$POWER_TIMEOUTS" ] && POWER_TIMEOUTS="/home/jhonayo/.config/qtile/scripts/power-timeouts.sh"

CONF="$HOME/.config/qtile/power.conf"
if [ -f "$CONF" ]; then
    # shellcheck source=/dev/null
    source "$CONF"
fi
CURR=${SUSPEND_SEC:-900}
if [ "${SUSPEND_TYPE:-suspend}" = "nothing" ]; then
    CURR=0
fi

fmt() {
    if [ "$1" -eq 0 ] 2>/dev/null; then echo "Nunca"; else echo "$(( $1 / 60 )) min"; fi
}
CURR_FMT=$(fmt "$CURR")

STEPS=(300 600 900 1800 3600 0)
LABELS=("5 min" "10 min" "15 min" "30 min" "60 min" "Nunca")

options=""
for i in "${!STEPS[@]}"; do
    sec=${STEPS[$i]}
    label=${LABELS[$i]}
    icon="system-suspend-symbolic"
    if [ "$sec" -eq "$CURR" ] 2>/dev/null; then
        label="● $label (actual)"
    fi
    options+="$label\0icon\x1f$icon\n"
done
options+="Back\0icon\x1fgo-previous-symbolic"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "💤 Suspensión ($CURR_FMT)" -theme "$THEME")
[ -z "$chosen" ] && exit 0

case "$chosen" in
    *"Back"*)
        if [ "$CALLER" = "config" ]; then exec "$HOME/.config/rofi/scripts/system/config.sh"; else exec "$HOME/.config/rofi/scripts/system/power.sh"; fi
        ;;
    *"5 min"*) "$POWER_TIMEOUTS" suspend 300 ;;
    *"10 min"*) "$POWER_TIMEOUTS" suspend 600 ;;
    *"15 min"*) "$POWER_TIMEOUTS" suspend 900 ;;
    *"30 min"*) "$POWER_TIMEOUTS" suspend 1800 ;;
    *"60 min"*) "$POWER_TIMEOUTS" suspend 3600 ;;
    *"Nunca"*) "$POWER_TIMEOUTS" suspend 0 ;;
esac
