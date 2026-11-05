#!/usr/bin/env bash
# Bar icon for light/dark mode: moon in dark mode, sun in light mode
[ "$(theme-mode)" = light ] && echo $'\U000F0599' || echo $'\U000F0594'
