#!/usr/bin/env bash
# yt-lista.sh — Convierte una playlist/mix/video de YouTube en .m3u + .txt
# Uso:
#   yt-lista.sh URL [nombre]   (modo directo)
#   yt-lista.sh                (modo guiado: pide link y nombre)
#   URL: playlist (list=...), mix (list=RD...), video o canal
#   nombre: base de los archivos (vacio = titulo de la lista o fecha)
# Salida: ~/Música/listas-youtube/<nombre>.m3u  +  .txt (juntos)
set -euo pipefail

OUTDIR="$HOME/Música/listas-youtube"
mkdir -p "$OUTDIR"
# Tope de canciones por extraccion (evita ráfagas que banean la IP).
# Cambiar con: YT_LIMITE=200 crear-lista URL nombre
MAX_TEMAS="${YT_LIMITE:-400}"

URL="${1:-}"
if [ -z "$URL" ]; then
  printf 'Link de YouTube: '
  IFS= read -r URL || true
fi
[ -n "$URL" ] || { echo "Sin link, nada que hacer."; exit 1; }

YTDLP="$HOME/.local/bin/yt-dlp"
[ -x "$YTDLP" ] || YTDLP="yt-dlp"

# Perfil Firefox con sesion de YouTube (primero ruta no estandar del .deb)
COOKIES=""
for p in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
  prof=$(find "$p" -maxdepth 1 -name "*.default*" -type d 2>/dev/null | head -n 1)
  if [ -n "$prof" ]; then COOKIES="firefox:$prof"; break; fi
done
[ -n "$COOKIES" ] || { echo "No encontre perfil Firefox (logueate en YouTube primero)"; exit 1; }

if [ $# -ge 2 ]; then
  BASE="$2"
else
  BASE=""
  if [ -t 0 ]; then
    printf 'Nombre (vacio = automatico): '
    IFS= read -r BASE || true
  fi
  if [ -z "$BASE" ]; then
    BASE=$("$YTDLP" --flat-playlist --print "%(playlist_title)s" \
      --cookies-from-browser "$COOKIES" "$URL" 2>/dev/null | head -n 1)
    # video suelto devuelve "NA" como titulo → usar fecha
    [ -z "$BASE" ] || [ "$BASE" = "NA" ] && BASE="lista-$(date +%F)"
  fi
fi
BASE=$(echo "$BASE" | tr '/' '-' | tr -s ' ' | sed 's/^ *//;s/ *$//')

M3U="$OUTDIR/$BASE.m3u"
TXT="$OUTDIR/$BASE.txt"
TMP=$(mktemp)
echo "extrayendo (~1 min por cada 200 temas, puedes seguir trabajando)..."
"$YTDLP" --flat-playlist --playlist-end "$MAX_TEMAS" --sleep-requests 1 \
  --print "%(title)s | https://youtu.be/%(id)s" \
  --cookies-from-browser "$COOKIES" "$URL" 2>/dev/null \
  | grep " | https://" > "$TMP" &
pid=$!
i=0
while kill -0 $pid 2>/dev/null; do
  sleep 2; i=$((i + 2))
  printf '\r extrayendo... %s temas (%ss)' "$(wc -l < "$TMP")" "$i"
done
wait "$pid" || true
printf '\n'
N=$(wc -l < "$TMP")
if [ "$N" -eq 0 ]; then
  echo "No se extrajo nada (¿link privado, mix vacio o bloqueo de YouTube?)"
  rm -f "$TMP"; exit 1
fi
{
  echo "#EXTM3U"
  while IFS= read -r l; do
    t="${l% | *}"; u="${l##* | }"
    printf '#EXTINF:-1,%s\n%s\n' "$t" "$u"
  done < "$TMP"
} > "$M3U"
cp "$TMP" "$TXT"; rm -f "$TMP"
echo "$N canciones → $M3U"
echo "titulos     → $TXT"
echo "reproducir: mpv \"$M3U\""
echo "aleatorio:  mpv --shuffle \"$M3U\""
