#!/bin/bash
# rofi-window.sh — cambia a cualquier ventana y la restaura si estaba minimizada.
# (rofi enfoca pero Qtile no des-minimiza solo: _do_focus ignora ventanas ocultas)
# Flujo: Super+Shift+m minimiza → Super+w → Enter restaura.
export DISPLAY="${DISPLAY:-:1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
QTILE_BIN="$(command -v qtile || echo "$HOME/.local/bin/qtile")"
rofi -show window -theme ~/.config/rofi/themes/keyhelp.rasi \
    -p "ventanas" \
    -mesg "Escribe para filtrar  •  Enter para ir (restaura minimizadas)" \
    || exit 0
sleep 0.2
if "$QTILE_BIN" cmd-obj -o window -f info 2>/dev/null | grep -q '"minimized": true'; then
    "$QTILE_BIN" cmd-obj -o window -f toggle_minimize >/dev/null
fi
