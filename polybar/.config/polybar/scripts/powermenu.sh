#!/usr/bin/env bash
# Power menu for polybar (rofi)
choice=$(printf '%s\n' "󰌾  Lock" "󰤄  Suspend" "󰍃  Log out" "󰜉  Reboot" "󰐥  Shut down" |
  # No search bar; top-right corner with the same offset as dunst (15, 57),
  # so it lines up with the bar and the notifications.
  rofi -dmenu -i -no-custom -p "Power" -theme-str '
    window   { width: 140px; location: north east; anchor: north east; x-offset: -15px; y-offset: 57px; }
    mainbox  { children: [ listview ]; padding: 6px 0; }
    listview { lines: 5; padding: 0; margin: 0; }
    element  { margin: 0; children: [ element-text ]; }')
case "$choice" in
  *Lock)      ~/.config/i3/scripts/lock.sh ;;
  *Suspend)   systemctl suspend ;;
  *"Log out") i3-msg exit ;;
  *Reboot)    systemctl reboot ;;
  *"Shut down") systemctl poweroff ;;
esac
