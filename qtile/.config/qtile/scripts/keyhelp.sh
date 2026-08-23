#!/bin/bash
# keyhelp.sh — ventana flotante de atajos (Opción B: auto-generado desde keys.py)
# Click derecho en astronauta → rofi -dmenu temático
SET_DIR="$(cd "$(dirname "$0")" && pwd)"
GEN="$SET_DIR/gen-keyhelp.py"

if [ -x "$GEN" ]; then
    python3 "$GEN" | rofi -dmenu -i \
        -theme ~/.config/rofi/themes/keyhelp.rasi \
        -p "󰌌 Atajos Qtile" \
        -mesg "Escribe para filtrar  •  Enter/Esc para cerrar  •  Click derecho en 󰏆 para reabrir"
else
    # fallback hardcodeado
    cat <<'EOF' | rofi -dmenu -i -theme ~/.config/rofi/themes/keyhelp.rasi -p "󰌌 Atajos Qtile"
󰘳 BASICOS
Super + Enter → Terminal
Super + e → Archivos
EOF
fi
