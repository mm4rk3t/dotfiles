#!/usr/bin/env zsh
# One run at a time: a new palette takes ~10 s the first time wallust sees an
# image, and a second theme switch or wallpaper change meanwhile would race it
# (doubled bars, colors from the wrong wallpaper or mode). flock(1) holds the
# lock until we exit; the fd loop below keeps it out of the bar and tray apps
if [[ -z ${SET_WALLPAPER_LOCKED:-} ]]; then
    SET_WALLPAPER_LOCKED=1 exec flock "$HOME/.cache/set_wallpaper.lock" "$0" "$@"
fi
# Close fds inherited from whoever launched us. polybar's click handler passes
# its inotify fds (no CLOEXEC) through theme-mode; without this every bar and
# tray app started below inherits them, and they pile up 3 per theme switch
# until fs.inotify.max_user_instances runs out
for fd in /proc/$$/fd/<3->(N:t); do { exec {fd}>&- } 2>/dev/null; done
# i3 (started by lightdm, which skips ~/.zprofile) has no ~/.local/bin in PATH.
# The bars started below inherit our PATH, and their theme module calls
# theme-mode for both the icon and the click, so put it back here
[[ :$PATH: == *:$HOME/.local/bin:* ]] || export PATH=$HOME/.local/bin:$PATH
# Wallpaper: the image given as $1 (random-wallpaper), else the one already
# set when this is a light/dark switch, else the pinned one (login, i3 restart)
PINNED=$HOME/Pictures/wallpapers/ethiopian-manuscripts.jpg
if [[ -n ${1:-} ]]; then
    WALL=$1
elif [[ -n ${THEME_SWITCH:-} ]]; then
    WALL=$(sed -n "s/.*'\(.*\)'.*/\1/p" ~/.fehbg 2>/dev/null | tail -1)
    [[ -f $WALL ]] || WALL=$PINNED
else
    WALL=$PINNED
fi
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
