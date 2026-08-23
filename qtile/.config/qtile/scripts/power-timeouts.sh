#!/bin/bash
# power-timeouts.sh — ajusta tiempos de apagado pantalla / bloqueo / suspensión
# Uso: power-timeouts.sh [show|short|long|custom <sec>|off]
#  show   → muestra estado actual
#  short  → 5 min pantalla, 10 min suspensión
#  long   → 30 min pantalla, 1h suspensión (para procesos largos)
#  custom <sec> → pantalla <sec>, suspensión <sec*2>
#  off    → desactiva suspensión (útil para procesos largos, como pides)
# Afecta: gsettings idle-delay, DPMS (xset), y systemd sleep-inactive

set -e

show_status() {
    echo "=== Estado actual ==="
    echo -n "GNOME idle-delay (pantalla): "; gsettings get org.gnome.desktop.session idle-delay
    echo -n "DPMS Standby/Suspend/Off: "; xset q | grep -A1 "DPMS" | tr -d '\n'; echo
    echo -n "Screensaver lock: "; gsettings get org.gnome.desktop.screensaver lock-enabled; echo " (xss-lock maneja i3lock)"
    echo -n "Power sleep-inactive-ac-type: "; gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
    echo -n "Power sleep-inactive-ac-timeout: "; gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout
    echo
    echo "Bloqueo manual: Control Center → Power → Bloquear (loginctl lock-session → xss-lock → i3lock)"
    echo "Para auto-bloqueo futuro: xss-lock + xautolock (no activo por ahora, solo manual)"
}

set_timeouts() {
    local screen_sec=$1
    local suspend_sec=$2
    local suspend_type=$3  # 'nothing' o 'suspend'
    echo "→ Pantalla: ${screen_sec}s, Suspensión: ${suspend_type} ${suspend_sec}s"
    gsettings set org.gnome.desktop.session idle-delay "uint32 $screen_sec"
    gsettings set org.gnome.desktop.screensaver idle-activation-enabled true
    gsettings set org.gnome.desktop.screensaver lock-enabled true
    # DPMS xset (Standby/Suspend/Off iguales)
    xset s "$screen_sec" "$screen_sec"
    xset dpms "$screen_sec" "$screen_sec" "$screen_sec"
    # systemd/GNOME power: suspensión tras inactividad
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type "'$suspend_type'"
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout "$suspend_sec"
    notify-send "⏱ Tiempos ajustados" "Pantalla ${screen_sec}s • Suspensión ${suspend_type} ${suspend_sec}s" -t 2000
}

case "$1" in
    show|"")
        show_status
        ;;
    short)
        set_timeouts 300 600 nothing  # 5 min pantalla, sin suspensión (seguro para procesos)
        ;;
    long)
        set_timeouts 1800 3600 nothing  # 30 min / sin suspensión
        ;;
    off)
        set_timeouts 600 0 nothing
        echo "Suspensión desactivada (ideal para procesos largos)"
        ;;
    custom)
        if [ -z "$2" ]; then echo "Uso: $0 custom <segundos>"; exit 1; fi
        set_timeouts "$2" $(( $2 * 2 )) nothing
        ;;
    suspend-on)
        # activa suspensión (si quieres que sí suspenda)
        set_timeouts 600 1800 suspend
        ;;
    *)
        echo "Uso: $0 [show|short|long|off|custom <sec>|suspend-on]"
        exit 1
        ;;
esac
