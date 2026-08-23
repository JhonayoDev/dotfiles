#!/bin/bash
# start_qtile.sh — wrapper para GDM: configura monitores ANTES de Qtile
# Fuente única: ~/.config/qtile/scripts/monitors.sh (sin --scale, 1 evento RandR)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MONITORS_SCRIPT="$SCRIPT_DIR/monitors.sh"

# Fallback a dotfiles/scripts si no existe en config
if [ ! -x "$MONITORS_SCRIPT" ]; then
    MONITORS_SCRIPT="/home/jhonayo/dotfiles/scripts/monitors.sh"
fi

if [ -x "$MONITORS_SCRIPT" ]; then
    bash "$MONITORS_SCRIPT"
fi

# Arrancar Qtile
exec /home/jhonayo/.local/bin/qtile start
