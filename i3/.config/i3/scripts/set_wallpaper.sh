#!/usr/bin/env zsh
# Pinned wallpaper. For a random one instead:
#   WALL=$(find ~/Pictures/wallpapers -type f | shuf -n1)
WALL=~/Pictures/wallpapers/pink-clouds.png
feh --bg-fill "$WALL"
# PNG copy for i3lock (lock screen shows the same wallpaper)
magick "$WALL" -resize 1920x1080^ -gravity center -extent 1920x1080 "$HOME/.cache/lock-wallpaper.png"
# Palette follows light/dark mode (theme-mode); the bar and rofi need its files
[[ -f ~/.cache/theme-mode.ini ]] || theme-mode apply
MODE=$(cat ~/.cache/theme-mode 2>/dev/null || echo dark)
"$HOME/.cargo/bin/wallust" run -p "${MODE}16" "$WALL"
# GTK theme recolored with the new accent (new GTK windows pick it up)
gtk-theme-wallust >/dev/null
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

# Bring the tray back open/closed as it was before the restart
setsid -f ~/.config/polybar/scripts/traytoggle.sh apply >/dev/null 2>&1 </dev/null

# Tray icons that only pick their light/dark variant at startup keep the old
# mode's look after a theme switch, so restart them (only when theme-mode ran
# us, not on every i3 reload)
if [[ -n ${THEME_SWITCH:-} ]]; then
    # volumeicon redraws its icon only when the volume changes
    if pgrep -x volumeicon >/dev/null; then
        pkill -x volumeicon
        setsid -f volumeicon >/dev/null 2>&1 </dev/null
    fi
    # Notion Electron picks tray.png from icons/{dark,light} only at launch.
    # SIGKILL: SIGTERM/INT/HUP all make Electron crash (SIGILL + core dump)
    # halfway through shutdown anyway, and its only clean quit is the tray
    # menu. Tabs survive: they're written to config.json as they change.
    if pgrep -x notion-electron >/dev/null; then
        # Hidden in the tray = not managed by i3 (a window on another
        # workspace still is), so check the i3 tree, not X visibility
        hidden=1
        i3-msg -t get_tree | grep -q '"class":"notion-electron"' && hidden=
        # A Notion started a few seconds ago (e.g. by the previous theme
        # switch) may not have mapped its window yet: don't send it to the tray
        (( $(ps -o etimes= -p "$(pgrep -o -x notion-electron)") < 20 )) && hidden=
        pkill -KILL -x notion-electron
        for _ in $(seq 50); do pgrep -x notion-electron >/dev/null || break; sleep 0.1; done
        if [[ -n $hidden ]]; then
            # Was in the tray: come back in the tray only
            setsid -f "/opt/Notion Electron/notion-electron" --disable-backgrounding-occluded-windows \
                --hide-on-startup >/dev/null 2>&1 </dev/null
        else
            # Window was open: via the desktop entry, same flags as from rofi
            setsid -f gtk-launch notion-electron >/dev/null 2>&1 </dev/null
        fi
    fi
fi
