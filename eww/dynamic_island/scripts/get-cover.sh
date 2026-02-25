#!/bin/bash
# ============================================================
# get-cover.sh — Extrae el cover art de la canción actual en MPD
#
# MÉTODOS (en orden de prioridad):
#   1. rmpc albumart   → pide el cover directo a MPD (más limpio)
#   2. ffmpeg          → extrae el cover embebido en el archivo de audio
#   3. cover.jpg/png   → busca imagen en el directorio del archivo
#   4. fallback        → devuelve la ruta del placeholder
#
# USO:
#   bash get-cover.sh
#   Imprime en stdout la ruta absoluta a la imagen del cover.
#   Siempre imprime algo (nunca vacío) para no crashear eww.
#
# PROBAR MANUALMENTE:
#   bash get-cover.sh
#   → debería imprimir algo como /tmp/mpd-cover.png
#   Verificar que es imagen válida:
#   file $(bash get-cover.sh)
#
# DEPENDENCIAS:
#   rmpc    → albumart (método 1)
#   ffmpeg  → extracción embebida (método 2)
#   mpc     → obtener ruta del archivo actual
# ============================================================

COVER_OUT="/tmp/mpd-cover.png"
FALLBACK="/tmp/mpd-cover-fallback.png"

# ── Crear fallback si no existe ───────────────────────────
# Evita que eww reciba ruta a archivo inexistente
ensure_fallback() {
  if [ ! -f "$FALLBACK" ]; then
    ffmpeg -y -f lavfi -i color=c=black:size=100x100 \
      -frames:v 1 "$FALLBACK" 2>/dev/null || true
  fi
}

# ── MÉTODO 1: rmpc albumart ───────────────────────────────
# Exit codes de rmpc albumart:
#   0 = éxito, 1 = error, 2 = no hay albumart, 3 = no hay canción
try_rmpc() {
  rmpc albumart "$COVER_OUT" 2>/dev/null
  local exit_code=$?
  if [ $exit_code -eq 0 ] && [ -s "$COVER_OUT" ]; then
    echo "$COVER_OUT"
    return 0
  fi
  return 1
}

# ── MÉTODO 2: ffmpeg desde el archivo de audio ────────────
try_ffmpeg() {
  local file
  file=$(mpc -f '%file%' current 2>/dev/null)
  [ -z "$file" ] && return 1

  # Leer music_directory del config — soporta comillas simples y dobles
  local music_dir
  music_dir=$(grep -i "^music_directory" \
    ~/.config/mpd/mpd.conf /etc/mpd.conf 2>/dev/null |
    head -1 | awk '{print $2}' | tr -d "\"'")
  music_dir="${music_dir/#\~/$HOME}"

  local full_path="$music_dir/$file"
  [ ! -f "$full_path" ] && return 1

  ffmpeg -y -i "$full_path" -an -vcodec copy "$COVER_OUT" 2>/dev/null
  [ -s "$COVER_OUT" ] && echo "$COVER_OUT" && return 0
  return 1
}

# ── MÉTODO 3: imagen en el directorio del álbum ───────────
try_folder_art() {
  local file
  file=$(mpc -f '%file%' current 2>/dev/null)
  [ -z "$file" ] && return 1

  local music_dir
  music_dir=$(grep -i "^music_directory" \
    ~/.config/mpd/mpd.conf /etc/mpd.conf 2>/dev/null |
    head -1 | awk '{print $2}' | tr -d "\"'")
  music_dir="${music_dir/#\~/$HOME}"

  local dir="$music_dir/$(dirname "$file")"

  for name in cover Cover folder Folder album Album artwork Artwork front Front; do
    for ext in jpg jpeg png webp; do
      local candidate="$dir/$name.$ext"
      if [ -f "$candidate" ]; then
        cp "$candidate" "$COVER_OUT"
        echo "$COVER_OUT"
        return 0
      fi
    done
  done
  return 1
}

# ── MAIN ──────────────────────────────────────────────────
ensure_fallback
try_rmpc && exit 0
try_ffmpeg && exit 0
try_folder_art && exit 0
echo "$FALLBACK"
