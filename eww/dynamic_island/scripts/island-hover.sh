#!/bin/bash
# ~/.config/eww/scripts/island-hover.sh
# Uso: island-hover.sh enter | leave

ACTION=$1
LOCK="/tmp/island-hover.lock"

case "$ACTION" in
enter)
  # Cancelar cualquier leave pendiente
  rm -f "$LOCK"
  eww update island_expanded=true
  ;;
leave)
  # Esperar 120ms — si en ese tiempo llega otro enter, cancelar
  touch "$LOCK"
  sleep 0.12
  if [ -f "$LOCK" ]; then
    rm -f "$LOCK"
    eww update island_expanded=false
  fi
  ;;
esac
