#!/usr/bin/env bash

STATE_FILE="$HOME/.cache/mpd_last_volume"
CMD="$1"
VALUE="$2"

get_volume() {
  VOL=$(mpc volume 2>/dev/null | grep -o '[0-9]\+' | head -n1)

  if [ -z "$VOL" ]; then
    echo 0
  else
    echo "$VOL"
  fi
}

case "$CMD" in
up)
  mpc volume +5 >/dev/null
  ;;
down)
  mpc volume -5 >/dev/null
  ;;
mute)
  CURRENT=$(get_volume)

  if [ "$CURRENT" -gt 0 ]; then
    echo "$CURRENT" >"$STATE_FILE"
    mpc volume 0 >/dev/null
  else
    if [ -f "$STATE_FILE" ]; then
      LAST=$(cat "$STATE_FILE")
      mpc volume "$LAST" >/dev/null
    else
      mpc volume 50 >/dev/null
    fi
  fi
  ;;
get)
  get_volume
  ;;
set)
  if [ -z "$VALUE" ]; then
    echo "Usage: $0 set <0-100>" >&2
    exit 1
  fi
  mpc volume "$VALUE" >/dev/null
  ;;
*)
  echo "Usage: $0 <up|down|mute|get|set> [value]" >&2
  exit 1
  ;;
esac
