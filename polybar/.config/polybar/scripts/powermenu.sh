#!/usr/bin/env bash
# Power menu for polybar (rofi)
choice=$(printf '%s\n' "󰌾  Lock" "󰤄  Suspend" "󰍃  Log out" "󰜉  Reboot" "󰐥  Shut down" |
  rofi -dmenu -i -p "Power" -theme-str 'window {width: 220px; location: north east; anchor: north east; x-offset: -10px; y-offset: 40px;} listview {lines: 5;}')
case "$choice" in
  *Lock)      ~/.config/i3/scripts/lock.sh ;;
  *Suspend)   systemctl suspend ;;
  *"Log out") i3-msg exit ;;
  *Reboot)    systemctl reboot ;;
  *"Shut down") systemctl poweroff ;;
esac
