#!/bin/bash

cat <<EOF | rofi -dmenu \
  -theme ~/.config/rofi/themes/control-center.rasi \
  -p "󰌌 Atajos Qtile"
󰘳 BASICOS
Super + Enter → Terminal
Super + e → Archivos
Super + q → Cerrar ventana
Super + f → Fullscreen

󰖲 VENTANAS
Super + h/j/k/l → Foco
Super + Shift + h/j/k/l → Mover
Super + Ctrl + Flechas → Resize

󰍹 SISTEMA
Super + Ctrl + r → Reload
Super + Ctrl + q → Salir

󰆍 ROFI
Super + Space → Apps
Alt + Space → Control Center

󰕾 AUDIO
Vol+/Vol- → Volumen
Mute → Silenciar

󰃠 SCREENSHOT
Super + p → Región
Super + Shift + p → Completo
EOF
