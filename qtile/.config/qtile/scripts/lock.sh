#!/bin/bash
# lock.sh — bloqueo estilo GDM con i3lock-color (barra + blur + hora grande)
# Control Center → Power → Bloquear llama directo a este script
# Usa wallpaper de theme.py:wallpapers["primary"] y colores de colors.rasi
set -e
WALLPAPER="$HOME/.config/qtile/Wallpaper/the-milky-way.jpeg"
if [ -f "$HOME/.config/qtile/theme.py" ]; then
  PY_WALL=$(python3 -c "import sys; sys.path.insert(0, '$HOME/.config/qtile'); from theme import wallpapers; import os; print(os.path.expanduser(wallpapers.get('primary','')))" 2>/dev/null || echo "")
  if [ -n "$PY_WALL" ] && [ -f "$PY_WALL" ]; then
    WALLPAPER="$PY_WALL"
  fi
fi
# Colores del tema (apply-theme.py → colors.rasi)
BG0="07060D"
BG1="161C40"
ACCENT="048DB8"
FG0="A8E6FF"
if [ -f "$HOME/.config/rofi/themes/colors.rasi" ]; then
  BG0=$(grep -i "bg0:" "$HOME/.config/rofi/themes/colors.rasi" 2>/dev/null | grep -oE "#[0-9a-fA-F]{6}" | head -n1 | tr -d '#' || echo "$BG0")
  BG1=$(grep -i "bg1:" "$HOME/.config/rofi/themes/colors.rasi" 2>/dev/null | grep -oE "#[0-9a-fA-F]{6}" | head -n1 | tr -d '#' || echo "$BG1")
  ACCENT=$(grep -i "accent:" "$HOME/.config/rofi/themes/colors.rasi" 2>/dev/null | grep -oE "#[0-9a-fA-F]{6}" | head -n1 | tr -d '#' || echo "$ACCENT")
  FG0=$(grep -i "fg0:" "$HOME/.config/rofi/themes/colors.rasi" 2>/dev/null | grep -oE "#[0-9a-fA-F]{6}" | head -n1 | tr -d '#' || echo "$FG0")
fi
# Detecta i3lock-color (tiene --inside-color y --bar-indicator) vs i3lock vanilla vs xsecurelock
I3LOCK_BIN=""
for cand in /usr/bin/i3lock /usr/local/bin/i3lock /tmp/i3lock-color/build/i3lock; do
  if [ -x "$cand" ] && "$cand" --help 2>&1 | grep -q "Please see the manpage" && grep -q "inside-color" "$cand" 2>&1; then
    if strings "$cand" 2>/dev/null | grep -q "inside-color"; then
      I3LOCK_BIN="$cand"
      break
    fi
  fi
  if [ -x "$cand" ] && strings "$cand" 2>/dev/null | grep -q "bar-indicator"; then
    I3LOCK_BIN="$cand"
    break
  fi
done
if [ -z "$I3LOCK_BIN" ]; then
  for cand in /usr/bin/i3lock /usr/local/bin/i3lock /tmp/i3lock-color/build/i3lock; do
    if [ -x "$cand" ] && "$cand" -v 2>&1 | grep -q "git-"; then
      I3LOCK_BIN="$cand"
      break
    fi
  done
fi
USERNAME="$(whoami)"
HOSTNAME="$(hostname -s 2>/dev/null || echo "")"
if [ -n "$I3LOCK_BIN" ]; then
  IMG_ARGS=""
  if [ -f "$WALLPAPER" ]; then
    IMG_ARGS="-i $WALLPAPER --scale"
  fi
  exec "$I3LOCK_BIN" -n -e \
    --blur 7 \
    $IMG_ARGS \
    --clock --force-clock \
    --time-str="%H:%M" \
    --date-str="%A,  %d %Y" \
    --greeter-text="" \
    --time-color="${FG0}ff" \
    --date-color="${FG0}cc" \
    --greeter-color="00000000" \
    --time-font="JetBrainsMono Nerd Font" \
    --date-font="JetBrainsMono Nerd Font" \
    --greeter-font="JetBrainsMono Nerd Font" \
    --time-size=96 \
    --date-size=24 \
    --greeter-size=1 \
    --time-pos="w/2:h/2-60" \
    --date-pos="w/2:h/2+20" \
    --greeter-pos="-500:-500" \
    --ind-pos="-500:-500" \
    --bar-pos="w/2-200:h-30" \
    --bar-indicator \
    --bar-orientation=horizontal \
    --bar-count=30 \
    --bar-max-height=15 \
    --bar-base-width=400 \
    --bar-total-width=400 \
    --bar-step=10 \
    --bar-periodic-step=5 \
    --bar-color="${BG0}44" \
    --keyhl-color="${ACCENT}ff" \
    --inside-color="00000000" \
    --ring-color="00000000" \
    --insidever-color="00000000" \
    --ringver-color="00000000" \
    --insidewrong-color="00000000" \
    --ringwrong-color="00000000" \
    --bshl-color="FF5555ff" \
    --keyhl-color="${ACCENT}ff" \
    --verif-color="${FG0}ff" \
    --wrong-color="FF5555ff" \
    --modif-color="${ACCENT}ff" \
    --verif-text="verificando…" \
    --wrong-text="incorrecto" \
    --noinput-text="" \
    --lock-text="" \
    --lockfailed-text="" \
    >/dev/null 2>&1 &
  exit 0
fi
# Fallback: xsecurelock con mpv si está disponible
if command -v xsecurelock >/dev/null 2>&1; then
  if command -v mpv >/dev/null 2>&1 && [ -f "$WALLPAPER" ]; then
    export XSECURELOCK_SAVER=saver_mpv
    export XSECURELOCK_LIST_VIDEOS_COMMAND="echo '$WALLPAPER'"
    export XSECURELOCK_IMAGE_DURATION_SECONDS=3600
  else
    export XSECURELOCK_SAVER=saver_blank
    export XSECURELOCK_BACKGROUND_COLOR="#${BG0}"
  fi
  export XSECURELOCK_AUTH=auth_x11
  export XSECURELOCK_SHOW_USERNAME=1
  export XSECURELOCK_SHOW_HOSTNAME=0
  export XSECURELOCK_SHOW_DATETIME=1
  export XSECURELOCK_DATETIME_FORMAT="%H:%M  %d/%m/%y"
  export XSECURELOCK_PASSWORD_PROMPT=asterisks
  export XSECURELOCK_AUTH_BACKGROUND_COLOR="#${BG1}"
  export XSECURELOCK_AUTH_FOREGROUND_COLOR="#${FG0}"
  export XSECURELOCK_AUTH_WARNING_COLOR="#FF5555"
  export XSECURELOCK_BACKGROUND_COLOR="#${BG0}"
  export XSECURELOCK_FONT="JetBrainsMono Nerd Font 14"
  export XSECURELOCK_COMPOSITE_OBSCURER=1
  export XSECURELOCK_NO_COMPOSITE=0
  export XSECURELOCK_BLANK_DPMS_STATE=off
  export XSECURELOCK_DISCARD_FIRST_KEYPRESS=0
  xsecurelock >/dev/null 2>&1 &
  exit 0
fi
# Último fallback: i3lock vanilla
if command -v i3lock >/dev/null 2>&1; then
  if [ -f "$WALLPAPER" ]; then
    EXT_LOWER=$(echo "${WALLPAPER##*.}" | tr '[:upper:]' '[:lower:]')
    TMP_PNG="/tmp/i3lock-wallpaper.png"
    if [ "$EXT_LOWER" = "jpg" ] || [ "$EXT_LOWER" = "jpeg" ]; then
      if [ ! -f "$TMP_PNG" ] || [ "$WALLPAPER" -nt "$TMP_PNG" ]; then
        python3 -c "from PIL import Image; Image.open('$WALLPAPER').convert('RGB').save('$TMP_PNG', 'PNG')" 2>/dev/null && WALLPAPER="$TMP_PNG" || true
      else
        WALLPAPER="$TMP_PNG"
      fi
    fi
    if file "$WALLPAPER" 2>/dev/null | grep -qi "PNG"; then
      i3lock -n -e -i "$WALLPAPER" -t -c "$BG1" >/dev/null 2>&1 &
      exit 0
    fi
  fi
  i3lock -n -e -c "$BG1" >/dev/null 2>&1 &
fi
