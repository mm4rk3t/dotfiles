#!/usr/bin/env zsh
WALL=$(find ~/Pictures/wallpapers -type f | shuf -n1)
feh --bg-fill "$WALL"
"$HOME/.cargo/bin/wallust" run "$WALL"
dunstctl reload
i3-msg reload

pkill polybar

while pgrep -x polybar >/dev/null; do
    sleep 0.1
done

polybar my_bar &
