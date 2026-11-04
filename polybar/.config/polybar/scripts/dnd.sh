#!/usr/bin/env bash
# Do Not Disturb for dunst.
#   dnd.sh         -> print current icon (used by polybar hook)
#   dnd.sh toggle  -> toggle, then refresh the bar icon instantly
on=$'\U000F009A'; off=$'\U000F009B'
if [ "$1" = toggle ]; then
  dunstctl set-paused toggle
  polybar-msg action dnd hook 0 >/dev/null 2>&1
  exit 0
fi
[ "$(dunstctl is-paused)" = true ] && echo "$off" || echo "$on"
