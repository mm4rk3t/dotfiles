#!/usr/bin/env bash
# Show/hide the systray and remember it, so a polybar restart (theme switch,
# monitor change) brings the tray back the way it was.
#   traytoggle.sh toggle   flip the state (bar click)
#   traytoggle.sh apply    re-apply the saved state (after the bar starts)
STATE="$HOME/.cache/polybar-tray"
state() { cat "$STATE" 2>/dev/null || echo closed; }

apply() {
    # hook 0 = 󰅁 (closed), hook 1 = 󰅂 (open)
    if [[ $(state) == open ]]; then
        polybar-msg action systray module_show && polybar-msg action traytoggle hook 1
    else
        polybar-msg action systray module_hide && polybar-msg action traytoggle hook 0
    fi >/dev/null 2>&1
}

case "${1:-}" in
    toggle)
        [[ $(state) == open ]] && echo closed > "$STATE" || echo open > "$STATE"
        apply ;;
    apply)
        # The bar's IPC isn't up right after launch; retry for a few seconds
        for _ in $(seq 50); do apply && break; sleep 0.1; done ;;
    *) echo "usage: traytoggle.sh toggle|apply" >&2; exit 1 ;;
esac
