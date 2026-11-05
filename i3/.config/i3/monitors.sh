#!/bin/sh
# Enable the external monitor on whichever port it's plugged into (DP adapter or HDMI);
# force 1080p when its EDID read fails
primary=eDP-1
externals="DP-1 DP-2 HDMI-1 HDMI-2"

# `xrandr --query` re-probes every output and stalls the X server ~1s each time,
# so probe once and reuse the result
state=$(xrandr --query)

# No laptop panel (e.g. a desktop): the first connected output is primary
if ! printf '%s\n' "$state" | grep -q "^$primary connected"; then
    primary=$(printf '%s\n' "$state" | awk '$2 == "connected" { print $1; exit }')
fi

secondary=
for out in $externals; do
    [ "$out" = "$primary" ] && continue
    if printf '%s\n' "$state" | grep -q "^$out connected"; then
        secondary=$out
    else
        xrandr --output $out --off
    fi
done

if [ -z "$secondary" ]; then
    xrandr --output $primary --primary --auto
    exit 0
fi

if printf '%s\n' "$state" | sed -n "/^$secondary/,/^[A-Za-z]/p" | grep -q '^ *1920x1080 '; then
    mode=1920x1080
else
    mode=1920x1080_60
    xrandr --newmode $mode 148.50 1920 2008 2052 2200 1080 1084 1089 1125 +hsync +vsync 2>/dev/null
    xrandr --addmode $secondary $mode 2>/dev/null
fi

xrandr --output $primary --primary --auto --output $secondary --mode $mode --left-of $primary
