#!/usr/bin/env bash
# Toggle a small calendar popup (i3 floats it at the mouse, see i3 config)
pkill -f 'zenity --calendar --title=polybar-calendar' && exit 0
zenity --calendar --title=polybar-calendar --text="" >/dev/null 2>&1 &
