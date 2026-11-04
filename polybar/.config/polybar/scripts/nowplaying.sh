#!/usr/bin/env bash
# Now playing (MPRIS via playerctl); prints an empty line when nothing plays.
# Polled by polybar every second instead of `playerctl --follow`: a follow
# stream only prints on change, so a line lost while the bar starts up left
# the module blank until the next track.
command -v playerctl >/dev/null || { echo ""; exit 0; }
IFS='|' read -r status artist title < <(playerctl metadata --format '{{status}}|{{artist}}|{{title}}' 2>/dev/null)
[ -z "$title" ] && { echo ""; exit 0; }
icon=$'\U000F040A'; [ "$status" = Playing ] && icon=$'\U000F03E4'  # show the action: pause while playing
text="$title${artist:+ - $artist}"  # song first, so truncation cuts the artist
if [ ${#text} -gt 80 ]; then text="${text:0:79}"; text="${text%"${text##*[! ]}"}…"; fi
echo "$icon $text"
