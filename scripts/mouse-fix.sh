#!/usr/bin/env bash

DEVICE_NAME="Logitech MX Master 3S"

apply_remap() {
  DEVICE_ID=$(xinput list --id-only "$DEVICE_NAME" 2>/dev/null)

  if [ -n "$DEVICE_ID" ]; then
    xinput set-button-map "$DEVICE_ID" \
      1 2 3 4 5 6 7 0 0 11 12 13 14 15 16 17 18 19 20
    echo "[mouse-fix] Remap aplicado a ID $DEVICE_ID"
  fi
}

echo "[mouse-fix] Iniciando watcher..."

while true; do
  apply_remap
  sleep 5
done
