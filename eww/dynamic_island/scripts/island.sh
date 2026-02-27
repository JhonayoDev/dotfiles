#!/usr/bin/env bash

EWW="$HOME/.local/bin/eww/eww"
LOCK="$HOME/.cache/island-expanded.lock"

case "$1" in
open)
  if [[ ! -f "$LOCK" ]]; then
    $EWW close dynamic-island-compact
    $EWW open dynamic-island-expanded
    touch "$LOCK"
  fi
  ;;
close)
  if [[ -f "$LOCK" ]]; then
    $EWW close dynamic-island-expanded
    $EWW open dynamic-island-compact
    rm "$LOCK"
  fi
  ;;
esac
