#!/bin/bash
# power-screen.sh — ajusta apagado de pantalla (pasos cíclicos por minutos + Nunca)
# Muestra rofi con valores actuales y permite elegir 1/3/5/10/15/30/Nunca, default 5m
# Aplica via ~/.config/qtile/scripts/power-timeouts.sh screen <sec>

POWER_TIMEOUTS="$HOME/.config/qtile/scripts/power-timeouts.sh"
THEME="$HOME/.config/rofi/themes/power-menu.rasi"
# Fallback si se llama desde dotfiles sin expandir HOME
[ ! -x "$POWER_TIMEOUTS" ] && POWER_TIMEOUTS="$HOME/dotfiles/qtile/.config/qtile/scripts/power-timeouts.sh"
[ ! -x "$POWER_TIMEOUTS" ] && POWER_TIMEOUTS="/home/jhonayo/.config/qtile/scripts/power-timeouts.sh"

CONF="$HOME/.config/qtile/power.conf"
if [ -f "$CONF" ]; then
    # shellcheck source=/dev/null
    source "$CONF"
fi
CURR=${SCREEN_SEC:-300}

fmt() {
    if [ "$1" -eq 0 ] 2>/dev/null; then echo "Nunca"; else echo "$(( $1 / 60 )) min"; fi
}
CURR_FMT=$(fmt "$CURR")

STEPS=(60 180 300 600 900 1800 0)
LABELS=("1 min" "3 min" "5 min" "10 min" "15 min" "30 min" "Nunca")

options=""
for i in "${!STEPS[@]}"; do
    sec=${STEPS[$i]}
    label=${LABELS[$i]}
    icon="video-display-symbolic"
    [ "$sec" -eq 0 ] && icon="video-display-symbolic"
    if [ "$sec" -eq "$CURR" ] 2>/dev/null; then
        label="● $label (actual)"
    fi
    options+="$label\0icon\x1f$icon\n"
done
options+="Back\0icon\x1fgo-previous-symbolic"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "🖥 Pantalla ($CURR_FMT)" -theme "$THEME")
[ -z "$chosen" ] && exit 0

case "$chosen" in
    *"Back"*)
        if [ "$CALLER" = "config" ]; then exec "$HOME/.config/rofi/scripts/system/config.sh"; else exec "$HOME/.config/rofi/scripts/system/power.sh"; fi
        ;;
    *"1 min"*) "$POWER_TIMEOUTS" screen 60 ;;
    *"3 min"*) "$POWER_TIMEOUTS" screen 180 ;;
    *"5 min"*) "$POWER_TIMEOUTS" screen 300 ;;
    *"10 min"*) "$POWER_TIMEOUTS" screen 600 ;;
    *"15 min"*) "$POWER_TIMEOUTS" screen 900 ;;
    *"30 min"*) "$POWER_TIMEOUTS" screen 1800 ;;
    *"Nunca"*) "$POWER_TIMEOUTS" screen 0 ;;
esac
