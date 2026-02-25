#!/usr/bin/env bash

THEME="$HOME/.config/rofi/themes/rounded-custom.rasi"

# ── Layout grid igual que tu control center ──────────────────────
layout='
listview {
    lines: 6;
    columns: 1;
    spacing: 6px;
}
element {
    orientation: horizontal;
    children: [ element-icon, element-text ];
    padding: 10px 14px;
    spacing: 10px;
    border-radius: 14px;
}
element-icon {
    size: 32px;
    vertical-align: 0.5;
}
element-text {
    vertical-align: 0.5;
}
'

# ── Estado del adaptador ──────────────────────────────────────────
bt_status=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')

if [ "$bt_status" = "yes" ]; then
  toggle_label="Bluetooth: ON  →  Apagar"
  toggle_icon="bluetooth"
else
  toggle_label="Bluetooth: OFF  →  Encender"
  toggle_icon="bluetooth-disabled"
fi

# ── Construir lista de dispositivos ──────────────────────────────
# Formato rofi: "texto\0icon\x1fnombre_icono"
options="${toggle_label}\0icon\x1f${toggle_icon}\n"
options+="── Scan nuevos dispositivos ──\0icon\x1fsystem-search\n"

# Dispositivos ya paired
while IFS= read -r line; do
  mac=$(echo "$line" | awk '{print $1}')
  name=$(echo "$line" | cut -d' ' -f2-)

  # Ver si está conectado
  connected=$(bluetoothctl info "$mac" | grep -c "Connected: yes")

  if [ "$connected" -gt 0 ]; then
    label="✓ $name (conectado)"
    icon="bluetooth-active"
  else
    label="  $name"
    icon="bluetooth"
  fi

  options+="${label}\0icon\x1f${icon}\n"
done < <(bluetoothctl devices Paired | awk '{$1=""; print $2, substr($0, index($0,$3))}' | sed 's/^ //')

# ── Mostrar rofi ─────────────────────────────────────────────────
chosen=$(echo -e "$options" | rofi \
  -dmenu \
  -i \
  -p "Bluetooth" \
  -theme "$THEME" \
  -theme-str "$layout" \
  -show-icons)

[ -z "$chosen" ] && exit 0

# ── Acciones ─────────────────────────────────────────────────────
if [[ "$chosen" == *"Apagar"* || "$chosen" == *"Encender"* ]]; then
  if [ "$bt_status" = "yes" ]; then
    bluetoothctl power off
  else
    bluetoothctl power on
  fi

elif [[ "$chosen" == *"Scan"* ]]; then
  # Escanear 5 segundos y reabrir el menú
  notify-send "Bluetooth" "Escaneando dispositivos..." -t 2000
  bluetoothctl --timeout 5 scan on
  exec "$0" # relanza el script

else
  # Extraer nombre limpio (quitar el ✓ y "(conectado)")
  name=$(echo "$chosen" | sed 's/^✓ //' | sed 's/ (conectado)//' | xargs)
  mac=$(bluetoothctl devices | grep -F "$name" | awk '{print $2}')

  if [ -z "$mac" ]; then
    notify-send "Bluetooth" "No se encontró el dispositivo" -t 2000
    exit 1
  fi

  connected=$(bluetoothctl info "$mac" | grep -c "Connected: yes")

  if [ "$connected" -gt 0 ]; then
    notify-send "Bluetooth" "Desconectando $name..." -t 2000
    bluetoothctl disconnect "$mac"
  else
    notify-send "Bluetooth" "Conectando $name..." -t 2000
    bluetoothctl connect "$mac"
  fi
fi
