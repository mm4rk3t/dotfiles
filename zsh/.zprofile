# Read by the X session too: lightdm's Xsession starts i3 through a zsh login shell.

# Qt apps (qBittorrent, ...) follow the GTK theme: dark, wallust accent
export QT_QPA_PLATFORMTHEME=gtk3

# ~/.local/bin for the whole session (i3, polybar, rofi), not just interactive shells
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
