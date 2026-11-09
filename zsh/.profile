# Sourced by Fedora's X session (/etc/X11/xinit/xinitrc-common) before it
# starts i3, so the whole desktop (i3, polybar, rofi) gets ~/.local/bin.
# .zprofile does the same for zsh login shells; this one doesn't depend on that.
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
