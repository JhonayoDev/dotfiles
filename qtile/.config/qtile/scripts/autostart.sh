#!/bin/bash
INTERNAL="eDP-1"
EXT1="HDMI-1"
EXT2="HDMI-2"
EXT1_ON=$(xrandr | grep "^$EXT1 connected")
EXT2_ON=$(xrandr | grep "^$EXT2 connected")
if [ -n "$EXT1_ON" ] && [ -n "$EXT2_ON" ]; then
  xrandr --output $INTERNAL --off \
    --output $EXT2 --auto \
    --output $EXT1 --auto --primary --right-of $EXT2
elif [ -n "$EXT1_ON" ]; then
  xrandr --output $INTERNAL --off \
    --output $EXT1 --auto --primary
elif [ -n "$EXT2_ON" ]; then
  xrandr --output $INTERNAL --off \
    --output $EXT2 --auto --primary
else
  xrandr --output $INTERNAL --mode 1920x1200 --primary
fi

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
dunst &
