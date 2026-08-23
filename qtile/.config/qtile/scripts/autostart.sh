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
# Mouse buttons
pkill -f mouse-buttons.py 2>/dev/null
python3 "/home/jhonayo/dotfiles/scripts/mouse-buttons.py" &
python3 "/home/jhonayo/dotfiles/scripts/apply-theme.py" &
dunst &
