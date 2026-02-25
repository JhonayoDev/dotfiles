#!/bin/bash

chosen=$(printf "Apagar\nReiniciar\nCerrar sesión" | rofi -dmenu -p "Power" -theme ~/.config/rofi/themes/minimal.rasi)

case "$chosen" in
Apagar) systemctl poweroff ;;
Reiniciar) systemctl reboot ;;
"Cerrar sesión") xfce4-session-logout ;;
esac
