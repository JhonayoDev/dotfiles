#!/bin/bash
# autostart.sh — daemons de sesión Qtile
# Nota: la configuración de monitores ya no está aquí.
# Ahora se hace ANTES de Qtile vía start_qtile.sh -> monitors.sh (sin --scale, 1 evento RandR)
# Esto evita el doble refresh (barra mal → corrige) y el delay de --scale 1.12

picom --daemon &
/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &
eval $(gnome-keyring-daemon --start)
nm-applet &
blueman-applet &
setxkbmap us && echo "US" >/tmp/kb_layout

# Tema oscuro GTK
dbus-update-activation-environment --systemd DISPLAY XAUTHORITY
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
export GTK_THEME=Adwaita-dark
xsettingsd &
# Mouse buttons — ahora systemd --user para sobrevivir DPMS 600s/Bluetooth (ver services/mouse-buttons.service)
# Fallback si el servicio no está habilitado (fresh install sin enable)
if systemctl --user is-active --quiet mouse-buttons.service 2>/dev/null; then
    systemctl --user try-restart mouse-buttons.service 2>/dev/null || true
else
    # intenta iniciar servicio; si no existe, lanza directo (compatibilidad)
    if [ -f "$HOME/.config/systemd/user/mouse-buttons.service" ] || [ -f "$HOME/dotfiles/services/mouse-buttons.service" ]; then
        mkdir -p "$HOME/.config/systemd/user"
        cp -f "$HOME/dotfiles/services/mouse-buttons.service" "$HOME/.config/systemd/user/mouse-buttons.service" 2>/dev/null || true
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now mouse-buttons.service 2>/dev/null || python3 "$HOME/dotfiles/scripts/mouse-buttons.py" &
    else
        python3 "$HOME/dotfiles/scripts/mouse-buttons.py" &
    fi
fi
# Tiempos pantalla/suspensión — fuente única ~/.config/qtile/power.conf (default 5m/15m)
# Alinea gsettings idle-delay, xset s/dpms y GNOME sleep-inactive al login
if [ -x "$HOME/.config/qtile/scripts/power-timeouts.sh" ]; then
    "$HOME/.config/qtile/scripts/power-timeouts.sh" apply-all &
fi

# Al despertar de suspend: restaura DPMS y monitores (Ubuntu GNOME-like)
# xss-lock --transfer-sleep-lock ya bloquea antes de suspend; aquí aseguramos resume
# Hook systemd-sleep no necesario: Qtile screen_change + DPMS se restauran solos, pero forzamos
(sleep 2; xset dpms force on 2>/dev/null || true; "$HOME/.config/qtile/scripts/monitors.sh" 2>/dev/null || true) &

# Locker: i3lock-color (barra + blur + hora grande) — Power → Bloquear llama directo a lock.sh
# xss-lock queda como puente para `loginctl lock-session` y suspensiones (usa lock.sh que ahora es i3lock-color)
if command -v xss-lock >/dev/null 2>&1; then
    if ! pgrep -x xss-lock >/dev/null 2>&1; then
        xss-lock --transfer-sleep-lock -- "$HOME/.config/qtile/scripts/lock.sh" &
    fi
fi
python3 "/home/jhonayo/dotfiles/scripts/apply-theme.py" &
dunst &
