#!/bin/bash

HDMI1=$(xrandr | grep "HDMI-1 connected")
HDMI2=$(xrandr | grep "HDMI-2 connected")

if [[ -n "$HDMI1" && -n "$HDMI2" ]]; then
  # MODO DOCK — ambos monitores, Mac cerrado
  xrandr \
    --output eDP-1 --off \
    --output HDMI-2 --mode 1920x1080 --scale 1x1 --pos 0x0 \
    --output HDMI-1 --mode 1920x1080 --scale 1.12x1.12 --right-of HDMI-2 --primary

elif [[ -n "$HDMI1" && -z "$HDMI2" ]]; then
  # Solo Samsung + Mac abierto
  xrandr \
    --output eDP-1 --mode 1920x1200 --pos 0x0 \
    --output HDMI-1 --mode 1920x1080 --scale 1.12x1.12 --primary --right-of eDP-1 \
    --output HDMI-2 --off

elif [[ -z "$HDMI1" && -n "$HDMI2" ]]; then
  # Solo Lenovo + Mac abierto
  xrandr \
    --output eDP-1 --mode 1920x1200 --pos 0x0 \
    --output HDMI-2 --mode 1920x1080 --primary --right-of eDP-1 \
    --output HDMI-1 --off

else
  # Solo Mac
  xrandr \
    --output eDP-1 --mode 1920x1200 --scale 1x1 --primary \
    --output HDMI-1 --off \
    --output HDMI-2 --off
fi
