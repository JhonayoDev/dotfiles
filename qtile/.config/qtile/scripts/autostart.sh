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
# Teclado backlight: por defecto apagado + dock-aware (tapa cerrada / 2x HDMI)
# Siempre inicia en 0% si está en dock; si no, también fuerza 0 para "por defecto apagado"
# Si prefieres que en uso normal respete el último nivel, deja solo el if de dock
if grep -q "closed" /proc/acpi/button/lid/LID0/state 2>/dev/null || \
   { xrandr 2>/dev/null | grep -q "^HDMI-1 connected" && xrandr 2>/dev/null | grep -q "^HDMI-2 connected"; }; then
    brightnessctl --device "smc::kbd_backlight" set 0% -q 2>/dev/null &
else
    # por defecto apagado siempre (comenta esta línea si quieres que recuerde nivel en uso normal)
    brightnessctl --device "smc::kbd_backlight" set 0% -q 2>/dev/null &
fi
# Watcher automático: apaga al cerrar tapa aunque lo hayas encendido después del login
# Requiere python3-evdev y usuario en grupo input (ya OK)
if command -v python3 >/dev/null 2>&1 && python3 -c "import evdev" 2>/dev/null; then
    pkill -f kbd-lid-watcher.py 2>/dev/null || true
    python3 "$HOME/.config/qtile/scripts/kbd-lid-watcher.py" >> /tmp/kbd-lid-watcher.log 2>&1 &
fi

python3 "/home/jhonayo/dotfiles/scripts/apply-theme.py" &
dunst &
# LibrePods (AirPods: bateria, ANC, ear detection) — bandeja SNI vía snixembed.
# El wrapper espera al watcher SNI (librepods aborta si no existe) y lo reinicia.
if command -v librepods >/dev/null 2>&1; then
    pgrep -f "librepods-start.sh" >/dev/null 2>&1 \
        || "$HOME/dotfiles/scripts/librepods-start.sh" &
fi
# AirPods: al conectar, volver a A2DP (modo musica) por defecto.
pgrep -f "airpods-default-mode.sh" >/dev/null 2>&1 \
    || "$HOME/.config/qtile/scripts/airpods-default-mode.sh" &

