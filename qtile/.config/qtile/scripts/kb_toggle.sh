#!/bin/bash
CURRENT=$(setxkbmap -query | grep layout | awk '{print $2}')
if [ "$CURRENT" = "us" ]; then
  setxkbmap latam
  echo "ES" >/tmp/kb_layout
else
  setxkbmap us
  echo "US" >/tmp/kb_layout
fi
