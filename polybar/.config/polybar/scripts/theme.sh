#!/usr/bin/env bash
# Bar icon for light/dark mode: shows the mode a click switches to
# (sun in dark mode, moon in light mode)
[ "$(theme-mode)" = light ] && echo $'\U000F0594' || echo $'\U000F0599'
