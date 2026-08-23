#!/bin/bash
# monitors.sh — fuente única de configuración de monitores (sin escala)
# Decisión 2026-08-23: sin --scale para evitar doble refresh (ver README).
# Antes había un doble refresco: primero Qtile y luego el escalado.
# Se prioriza velocidad (1 evento RandR) sobre uniformidad perfecta de tamaño.
#
# Comportamiento:
#   2 HDMI → modo dock, eDP-1 apagado
#   1 HDMI → eDP + HDMI lado a lado
#   0 HDMI → solo eDP

HDMI1=$(xrandr | grep "^HDMI-1 connected")
HDMI2=$(xrandr | grep "^HDMI-2 connected")

if [[ -n "$HDMI1" && -n "$HDMI2" ]]; then
  # MODO DOCK — ambos monitores, Mac cerrado (eDP off)
  # Sin --scale: 1 solo evento RandR → evita doble reconfig de Qtile
  xrandr \
    --output eDP-1 --off \
    --output HDMI-2 --mode 1920x1080 --pos 0x0 \
    --output HDMI-1 --mode 1920x1080 --primary --right-of HDMI-2

elif [[ -n "$HDMI1" && -z "$HDMI2" ]]; then
  # Solo HDMI-1 (Samsung) + Mac abierto
  xrandr \
    --output eDP-1 --mode 1920x1200 --pos 0x0 \
    --output HDMI-1 --mode 1920x1080 --primary --right-of eDP-1 \
    --output HDMI-2 --off

elif [[ -z "$HDMI1" && -n "$HDMI2" ]]; then
  # Solo HDMI-2 (Lenovo) + Mac abierto
  xrandr \
    --output eDP-1 --mode 1920x1200 --pos 0x0 \
    --output HDMI-2 --mode 1920x1080 --primary --right-of eDP-1 \
    --output HDMI-1 --off

else
  # Solo Mac
  xrandr \
    --output eDP-1 --mode 1920x1200 --primary --pos 0x0 \
    --output HDMI-1 --off \
    --output HDMI-2 --off
fi

# Nota: variante con escala (causa doble refresh) archivada como ejemplo:
#   --output HDMI-1 --mode 1920x1080 --scale 1.12x1.12 --right-of HDMI-2
# Se dejó sin implementar para mantener 1 evento RandR.
