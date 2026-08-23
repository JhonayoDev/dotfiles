#!/bin/bash
# power-timeouts.sh — fuente única para tiempos de pantalla y suspensión
# Ajusta pantalla (idle-delay + DPMS xset) y suspensión (GNOME power) por separado
# Sin bloqueo automático: solo manual via Power → Bloquear (xss-lock → i3lock-color)
# Uso: power-timeouts.sh [show|screen <sec|0|never>|suspend <sec|0|never>|short|long|off]
#  show              → muestra estado
#  screen <sec|0>    → pantalla <sec> (0 = nunca), DPMS sincronizado
#  suspend <sec|0>   → suspensión <sec> (0 = nunca), tipo suspend/nothing
#  short/long/off    → compatibilidad (mapea a presets antiguos)
# Defaults: pantalla 5 min (300), suspensión 15 min (900) — se persiste en ~/.config/qtile/power.conf

set -e
CONF="$HOME/.config/qtile/power.conf"
mkdir -p "$(dirname "$CONF")"

# Carga o crea defaults 5m/15m
if [ ! -f "$CONF" ]; then
    echo "SCREEN_SEC=300" > "$CONF"
    echo "SUSPEND_SEC=900" >> "$CONF"
    echo "SUSPEND_TYPE=suspend" >> "$CONF"
fi
# shellcheck source=/dev/null
source "$CONF" 2>/dev/null || true
SCREEN_SEC=${SCREEN_SEC:-300}
SUSPEND_SEC=${SUSPEND_SEC:-900}
SUSPEND_TYPE=${SUSPEND_TYPE:-suspend}

save_conf() {
    echo "SCREEN_SEC=$SCREEN_SEC" > "$CONF"
    echo "SUSPEND_SEC=$SUSPEND_SEC" >> "$CONF"
    echo "SUSPEND_TYPE=$SUSPEND_TYPE" >> "$CONF"
}

fmt_time() {
    local s=$1
    if [ "$s" -eq 0 ] 2>/dev/null; then echo "Nunca"; return; fi
    if [ "$s" -lt 60 ]; then echo "${s}s"; elif [ $((s % 60)) -eq 0 ]; then echo "$((s/60)) min"; else echo "$((s/60))m $((s%60))s"; fi
}

show_status() {
    echo "=== Estado actual (fuente: $CONF) ==="
    echo "Pantalla: $(fmt_time "$SCREEN_SEC")  (idle-delay + DPMS)"
    if [ "$SUSPEND_SEC" -eq 0 ] 2>/dev/null || [ "$SUSPEND_TYPE" = "nothing" ]; then
        echo "Suspensión: Nunca"
    else
        echo "Suspensión: $(fmt_time "$SUSPEND_SEC") (suspend)"
    fi
    echo
    echo -n "GNOME idle-delay: "; gsettings get org.gnome.desktop.session idle-delay 2>&1 | cat
    echo -n "DPMS: "; xset q 2>&1 | grep -A1 "DPMS" | tr -d '\n' | cat; echo
    echo -n "sleep-inactive-ac-type: "; gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 2>&1 | cat
    echo -n "sleep-inactive-ac-timeout: "; gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 2>&1 | cat
    echo "xss-lock: $(pgrep -x xss-lock >/dev/null 2>&1 && echo "activo (bloqueo en suspend)" || echo "inactivo")"
}

apply_screen() {
    local sec=$1
    if [ "$sec" = "0" ] || [ "$sec" = "never" ] || [ "$sec" = "Nunca" ]; then
        sec=0
    fi
    SCREEN_SEC=$sec
    save_conf
    if [ "$sec" -eq 0 ] 2>/dev/null; then
        echo "→ Pantalla: Nunca"
        gsettings set org.gnome.desktop.session idle-delay "uint32 0" 2>&1 | cat
        gsettings set org.gnome.desktop.screensaver idle-activation-enabled false 2>&1 | cat || true
        xset s off 2>&1 | cat || true
        xset s noblank 2>&1 | cat || true
        xset -dpms 2>&1 | cat || true
        notify-send "🖥 Pantalla: Nunca" "No se apagará sola" -t 2000 2>/dev/null || true
    else
        echo "→ Pantalla: $(fmt_time "$sec")"
        gsettings set org.gnome.desktop.session idle-delay "uint32 $sec" 2>&1 | cat
        gsettings set org.gnome.desktop.screensaver idle-activation-enabled true 2>&1 | cat || true
        gsettings set org.gnome.desktop.screensaver lock-enabled true 2>&1 | cat || true
        xset s "$sec" "$sec" 2>&1 | cat || true
        xset dpms "$sec" "$sec" "$sec" 2>&1 | cat || true
        xset +dpms 2>&1 | cat || true
        xset s blank 2>&1 | cat || true
        notify-send "🖥 Pantalla: $(fmt_time "$sec")" "Apagado tras $(fmt_time "$sec")" -t 2000 2>/dev/null || true
    fi
}

apply_suspend() {
    local sec=$1
    if [ "$sec" = "0" ] || [ "$sec" = "never" ] || [ "$sec" = "Nunca" ]; then
        sec=0
        SUSPEND_SEC=0
        SUSPEND_TYPE=nothing
        save_conf
        echo "→ Suspensión: Nunca"
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type "'nothing'" 2>&1 | cat
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0 2>&1 | cat
        notify-send "💤 Suspensión: Nunca" "No suspenderá sola" -t 2000 2>/dev/null || true
    else
        SUSPEND_SEC=$sec
        SUSPEND_TYPE=suspend
        save_conf
        echo "→ Suspensión: $(fmt_time "$sec")"
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type "'suspend'" 2>&1 | cat
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout "$sec" 2>&1 | cat
        notify-send "💤 Suspensión: $(fmt_time "$sec")" "Suspenderá tras $(fmt_time "$sec")" -t 2000 2>/dev/null || true
    fi
}

# Aplica ambos al iniciar (para alinear tras login)
apply_all() {
    apply_screen "$SCREEN_SEC" >/dev/null 2>&1 || true
    apply_suspend "$SUSPEND_SEC" >/dev/null 2>&1 || true
}

case "$1" in
    show|"")
        show_status
        ;;
    screen)
        if [ -z "$2" ]; then echo "Uso: $0 screen <segundos|0|never>"; exit 1; fi
        apply_screen "$2"
        ;;
    suspend)
        if [ -z "$2" ]; then echo "Uso: $0 suspend <segundos|0|never>"; exit 1; fi
        apply_suspend "$2"
        ;;
    apply-all)
        apply_all
        ;;
    short)
        apply_screen 300; apply_suspend 0
        ;;
    long)
        apply_screen 1800; apply_suspend 0
        ;;
    off)
        apply_screen 0; apply_suspend 0
        ;;
    suspend-on)
        apply_suspend 900
        ;;
    custom)
        if [ -z "$2" ]; then echo "Uso: $0 custom <segundos>"; exit 1; fi
        apply_screen "$2"; apply_suspend $(( $2 * 3 ))
        ;;
    *)
        echo "Uso: $0 [show|screen <sec|0>|suspend <sec|0>|apply-all|short|long|off]"
        exit 1
        ;;
esac
