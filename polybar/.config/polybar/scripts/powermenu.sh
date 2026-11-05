#!/usr/bin/env bash
# Power menu for polybar (rofi)

# No search bar; top-right corner with the same offset as dunst (15, 57),
# so it lines up with the bar and the notifications. Entries highlight on
# hover and a single click picks one.
menu() { # menu PROMPT LINES [extra rofi args]
  local prompt=$1 lines=$2; shift 2
  rofi -dmenu -i -no-custom -p "$prompt" "$@" \
    -hover-select -me-select-entry "" -me-accept-entry MousePrimary \
    -theme-str "
    window   { width: 129px; location: north east; anchor: north east; x-offset: -15px; y-offset: 57px; }
    mainbox  { children: [ listview ]; padding: 6px; }
    listview { lines: $lines; padding: 0; margin: 0; }
    element  { margin: 0; children: [ element-text ]; }"
}

# Reboot and shut down ask first; "No" is the default so Enter is safe.
# No click-to-exit here: the confirm menu is shorter, so releasing the click
# that picked Reboot/Shut down lands outside it and would close it at once.
confirm() {
  [ "$(printf '%s\n' "No" "$1?" | menu "$1" 2 -no-click-to-exit)" = "$1?" ]
}

choice=$(printf '%s\n' "Lock" "Suspend" "Log out" "Reboot" "Shut down" | menu Power 5)
case "$choice" in
  *Lock)      ~/.config/i3/scripts/lock.sh ;;
  *Suspend)   systemctl suspend ;;
  *"Log out") i3-msg exit ;;
  *Reboot)    confirm Reboot && systemctl reboot ;;
  *"Shut down") confirm "Shut down" && systemctl poweroff ;;
esac
