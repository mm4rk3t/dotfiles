#!/usr/bin/env bash
# Windows-style tray overflow: the tray lives in a small stalonetray grid
# window that pops up under the bar's arrow when clicked.
#   traytoggle.sh toggle   show/hide the popup (bar click)
#   traytoggle.sh close    hide the popup (trayframe.py, on a click outside it)
#   traytoggle.sh apply    start the tray if needed, recolor it for the current
#                          theme and sync the bar arrow
# i3 has one border color for all windows (the accent once hovered/focused), so
# the popup has no i3 border: stalonetray sits inside trayframe.py, a GTK
# window with a subtle 1px border that also follows light/dark mode (SIGUSR1).
# The tray is never restarted on a theme switch: Electron apps (Slack, Spotify,
# ...) only dock at launch and would lose their icons. The frame is what i3
# manages and keeps in its scratchpad while hidden (see the i3 for_window rules).
DIR="$(dirname "$(readlink -f "$0")")"
COLS=4          # icons per row; the grid grows downwards
ICON=18         # icon size in px
GAP_Y=52        # popup top edge: bar offset (15) + bar height + border + gap
frame() { xdotool search --classname '^trayframe$' 2>/dev/null | head -1; }
tray() { xdotool search --classname '^stalonetray$' 2>/dev/null | head -1; }

# Visible = on a workspace other than i3's scratchpad
visible() {
    i3-msg -t get_tree | python3 -c '
import json, sys
def walk(n, ws=None):
    if n.get("type") == "workspace": ws = n["name"]
    if (n.get("window_properties") or {}).get("class") == "trayframe":
        sys.exit(0 if ws != "__i3_scratch" else 1)
    for c in n.get("nodes", []) + n.get("floating_nodes", []): walk(c, ws)
walk(json.load(sys.stdin)); sys.exit(1)'
}

# A click on the bar arrow while open first closes the popup (outside click),
# then runs toggle, which must not reopen it right away
CLOSED="${XDG_RUNTIME_DIR:-/tmp}/traytoggle-closed"
now_ms() { date +%s%3N; }
hide() { i3-msg -q '[class="^trayframe$"] move scratchpad'; arrow 0; now_ms > "$CLOSED"; }

arrow() { polybar-msg action traytoggle hook "$1" >/dev/null 2>&1; }   # 0 = 󰅀 (closed), 1 = 󰅃 (open)

start() {
    # stalonetray sometimes ignores SIGTERM; a stray one would keep the tray selection
    pkill -f "python3 $DIR/trayframe.py"; sleep 0.2; pkill -KILL -x stalonetray
    setsid -f python3 "$DIR/trayframe.py" \
        --icon-size "$ICON" --slot-size $((ICON + 8)) \
        --geometry "${COLS}x1" --max-geometry "${COLS}x0" --grow-gravity NW --icon-gravity NW \
        --kludges force_icons_size --decorations none --window-type normal \
        --skip-taskbar --window-strut none >/dev/null 2>&1 </dev/null
}

case "${1:-}" in
    toggle)
        [[ -z $(frame) ]] && { start; sleep 1; }
        if visible; then
            hide
        elif (( $(now_ms) - $(cat "$CLOSED" 2>/dev/null || echo 0) < 500 )); then
            :   # just closed by this same click
        else
            # Both --shell outputs set X/Y, so read the mouse X before anything else
            mx=$(xdotool getmouselocation --shell | sed -n 's/^X=//p')
            # Size the frame to what stalonetray wants for its docked icons, + 1px each side
            read -r w h < <(xprop -id "$(tray)" WM_NORMAL_HINTS 2>/dev/null |
                sed -n 's/.*minimum size: \([0-9]*\) by \([0-9]*\).*/\1 \2/p')
            w=${w:-$((COLS * (ICON + 8)))}; h=${h:-$((ICON + 8))}
            # The tray isn't managed by i3 inside the frame, so this sticks
            xdotool windowsize "$(tray)" "$w" "$h"
            w=$((w + 2)); h=$((h + 2))
            # scratchpad show opens on the focused workspace, which may be on the
            # other monitor: focus the output under the mouse (the clicked bar) first
            out=$(i3-msg -t get_outputs | python3 -c '
import json, sys
mx = int(sys.argv[1])
for o in json.load(sys.stdin):
    r = o["rect"]
    if o["active"] and r["x"] <= mx < r["x"] + r["width"]: print(o["name"]); break' "$mx")
            ox=$(i3-msg -t get_outputs | python3 -c '
import json, sys
print(next((o["rect"]["x"] + o["rect"]["width"] for o in json.load(sys.stdin) if o["name"] == sys.argv[1]), 99999))' "$out")
            x=$((mx - w / 2)); (( x + w > ox - 10 )) && x=$((ox - 10 - w)); (( x < 10 )) && x=10
            i3-msg -q "focus output $out; [class=\"^trayframe\$\"] scratchpad show, resize set $w $h, move absolute position $x $GAP_Y"
            arrow 1
        fi ;;
    close) visible && hide ;;
    apply)
        if [[ -z $(frame) || -z $(tray) ]]; then start
        else pkill -USR1 -f "python3 $DIR/trayframe.py"; fi
        # The bar's IPC isn't up right after launch; retry for a few seconds
        for _ in $(seq 50); do
            if visible; then arrow 1; else arrow 0; fi && break; sleep 0.1
        done ;;
    *) echo "usage: traytoggle.sh toggle|close|apply" >&2; exit 1 ;;
esac
