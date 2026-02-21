#!/usr/bin/env bash

# Detectar DISPLAY activo si no está seteado
if [ -z "$DISPLAY" ]; then
  export DISPLAY=$(who | grep -oP '\(:\d+\)' | head -1 | tr -d '()')
  [ -z "$DISPLAY" ] && export DISPLAY=:0
fi
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

DEVICE_NAME="Logitech MX Master 3S"
MAX_RETRIES=20
SLEEP_SECONDS=1

log() {
  echo "[mouse-fix] $1"
}

get_device_id() {
  xinput list --id-only "$DEVICE_NAME" 2>/dev/null
}

wait_for_x() {
  for i in $(seq 1 $MAX_RETRIES); do
    if xinput list >/dev/null 2>&1; then
      return 0
    fi
    sleep $SLEEP_SECONDS
  done
  return 1
}

wait_for_device() {
  for i in $(seq 1 $MAX_RETRIES); do
    ID=$(get_device_id)
    if [ -n "$ID" ]; then
      echo "$ID"
      return 0
    fi
    sleep $SLEEP_SECONDS
  done
  return 1
}

log "Esperando X11..."
wait_for_x || {
  log "X11 no disponible."
  exit 1
}

log "Buscando dispositivo..."
DEVICE_ID=$(wait_for_device) || {
  log "Dispositivo no encontrado."
  exit 1
}

log "Dispositivo encontrado con ID $DEVICE_ID"
log "Aplicando remapeo..."

xinput set-button-map "$DEVICE_ID" \
  1 2 3 4 5 6 7 0 0 11 12 13 14 15 16 17 18 19 20

log "Remapeo aplicado correctamente."
