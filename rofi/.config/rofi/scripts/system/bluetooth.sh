#!/bin/bash
# Gestor de bluetooth - solo dispositivos ya pareados
# Para parear nuevos usar blueman-manager desde el systray

THEME="$HOME/.config/rofi/themes/submenu.rasi"

# Estado del adaptador
bt_status=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')

if [ "$bt_status" = "yes" ]; then
  toggle_label="⏻  Bluetooth ON  →  Apagar"
else
  toggle_label="⏻  Bluetooth OFF  →  Encender"
fi

# Construir lista de dispositivos pareados
options="${toggle_label}\n"
options+="──────────────────────\n"

while IFS= read -r line; do
  mac=$(echo "$line" | awk '{print $2}')
  name=$(echo "$line" | cut -d' ' -f3-)
  connected=$(bluetoothctl info "$mac" 2>/dev/null | grep -c "Connected: yes")
  if [ "$connected" -gt 0 ]; then
    options+="✔  $name\n"
  else
    options+="   $name\n"
  fi
done < <(bluetoothctl devices Paired)

chosen=$(echo -e "$options" | rofi -dmenu -i -p "󰂯 Bluetooth" -theme "$THEME")
[ -z "$chosen" ] && exit 0

# Acciones
if [[ "$chosen" == *"Apagar"* ]]; then
  bluetoothctl power off
  notify-send "Bluetooth" "Adaptador apagado" -t 2000
elif [[ "$chosen" == *"Encender"* ]]; then
  bluetoothctl power on
  notify-send "Bluetooth" "Adaptador encendido" -t 2000
elif [[ "$chosen" == "──────────────────────" ]]; then
  exec "$0"
else
  # Conectar o desconectar dispositivo
  name=$(echo "$chosen" | sed 's/^[✔ ]*//' | xargs)
  mac=$(bluetoothctl devices Paired | grep -F "$name" | awk '{print $2}')
  [ -z "$mac" ] && notify-send "Bluetooth" "Dispositivo no encontrado" -t 2000 && exit 1

  connected=$(bluetoothctl info "$mac" 2>/dev/null | grep -c "Connected: yes")
  if [ "$connected" -gt 0 ]; then
    notify-send "Bluetooth" "Desconectando $name..." -t 2000
    bluetoothctl disconnect "$mac"
  else
    notify-send "Bluetooth" "Conectando $name..." -t 2000
    bluetoothctl connect "$mac"
  fi
fi
