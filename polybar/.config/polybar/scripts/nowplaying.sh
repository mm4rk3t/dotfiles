#!/usr/bin/env bash
# Now playing (MPRIS via playerctl); prints nothing when no player is active
command -v playerctl >/dev/null || exit 0
playerctl --follow metadata --format '{{status}}|{{artist}}|{{title}}' 2>/dev/null |
while IFS='|' read -r status artist title; do
  [ -z "$title" ] && { echo ""; continue; }
  icon=$'\U000F03E4'; [ "$status" = Playing ] && icon=$'\U000F040A'
  text="${artist:+$artist - }$title"
  [ ${#text} -gt 40 ] && text="${text:0:39}…"
  echo "$icon $text"
done
