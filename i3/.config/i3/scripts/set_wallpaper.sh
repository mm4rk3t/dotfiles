#!/usr/bin/env zsh
# Pinned wallpaper. For a random one instead:
#   WALL=$(find ~/Pictures/wallpapers -type f | shuf -n1)
WALL=~/Pictures/wallpapers/forest-clouds.jpg
feh --bg-fill "$WALL"
# PNG copy for i3lock (lock screen shows the same wallpaper)
magick "$WALL" -resize 1920x1080^ -gravity center -extent 1920x1080 "$HOME/.cache/lock-wallpaper.png"
# Palette follows light/dark mode (theme-mode); the bar and rofi need its files
[[ -f ~/.cache/theme-mode.ini ]] || ~/.local/bin/theme-mode apply
MODE=$(cat ~/.cache/theme-mode 2>/dev/null || echo dark)
"$HOME/.cargo/bin/wallust" run -p "${MODE}16" "$WALL"
# GTK theme recolored with the new accent (new GTK windows pick it up)
"$HOME/.local/bin/gtk-theme-wallust" >/dev/null
dunstctl reload
# Sun/moon icon on the bar
polybar-msg action theme hook 0 >/dev/null 2>&1
i3-msg reload

pkill polybar

while pgrep -x polybar >/dev/null; do
    sleep 0.1
done

# One bar per connected monitor; the tray goes on the primary one
polybar --list-monitors | while IFS=: read -r m rest; do
    if [[ $rest == *primary* ]]; then
        MONITOR=$m polybar my_bar &
    else
        MONITOR=$m polybar my_bar_secondary &
    fi
done
