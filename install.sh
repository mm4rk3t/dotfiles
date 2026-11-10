#!/usr/bin/env bash
# Bootstrap this i3 desktop on a fresh Fedora install.
#
#   git clone git@github.com:mm4rk3t/dotfiles.git ~/dotfiles
#   ~/dotfiles/install.sh              # everything
#   ~/dotfiles/install.sh --no-packages  # only link configs + regenerate colors
#
# Safe to re-run: packages already installed are skipped, and any existing
# file that would be replaced by a symlink is moved to ~/.dotfiles-backup/<ts>/.
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_PACKAGES=(i3 polybar rofi alacritty picom wallust gtk zsh nvim wallpaper claude codewhale autostart bin fonts fontconfig volumeicon applications xfce)
ENGRAM_VERSION=3.6.0
CODEWHALE_VERSION=0.10.2
NOTION_ELECTRON_VERSION=2.5.0
# No checksum file in its releases: pinned hash of Notion_Electron-$NOTION_ELECTRON_VERSION-x86_64.rpm
NOTION_ELECTRON_SHA256=513e414193e32a0965ea6dec00c7152f434fdadd36fbe19066dd156215a3005d
DEFAULT_WALLPAPER="$HOME/Pictures/wallpapers/pink-clouds.png"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

INSTALL_PACKAGES=1
[[ "${1:-}" == "--no-packages" ]] && INSTALL_PACKAGES=0

log() { printf '\033[1;31m==>\033[0m %s\n' "$*"; }

# Read a package list, dropping comments and blank lines.
read_list() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1"; }

install_packages() {
    if ! command -v dnf >/dev/null; then
        log "dnf not found - this installer targets Fedora. Install packages/dnf.txt manually."
        return
    fi

    log "Installing dnf packages"
    sudo dnf install -y dnf-plugins-core
    # RPM Fusion (free + nonfree): steam lives in nonfree
    if ! rpm -q rpmfusion-nonfree-release >/dev/null; then
        local fedora
        fedora="$(rpm -E %fedora)"
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$fedora.noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$fedora.noarch.rpm"
    fi
    mapfile -t pkgs < <(read_list "$DOTFILES/packages/dnf.txt")
    sudo dnf install -y "${pkgs[@]}"

    log "Enabling COPR repos"
    while read -r repo pkg; do
        sudo dnf copr enable -y "$repo"
        if rpm -q "$pkg" >/dev/null; then
            echo "$pkg already installed"
        elif [[ "$pkg" == i3lock-color ]] && rpm -q i3lock >/dev/null; then
            # i3lock-color ships the same files as the stock i3lock but doesn't
            # declare a conflict, so --allowerasing won't remove it. Swap explicitly.
            sudo dnf swap -y i3lock i3lock-color
        else
            sudo dnf install -y "$pkg"
        fi
    done < <(read_list "$DOTFILES/packages/copr.txt")

    log "Installing cargo crates"
    while read -r crate version; do
        if cargo install --list | grep -q "^$crate v$version:"; then
            echo "$crate $version already installed"
        else
            cargo install --locked "$crate" --version "$version"
        fi
    done < <(read_list "$DOTFILES/packages/cargo.txt")

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log "Installing oh-my-zsh"
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
            "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi

    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
        log "Setting zsh as login shell"
        sudo chsh -s "$(command -v zsh)" "$USER"
    fi
}

install_gtk_theme() {
    log "Installing GTK theme Material-Black-Blueberry"
    mkdir -p "$HOME/.local/share/themes"
    tar -xzf "$DOTFILES/assets/Material-Black-Blueberry.tar.gz" -C "$HOME/.local/share/themes"
}

# Move real files out of the way so stow can create its symlinks.
backup_conflicts() {
    local pkg=$1 rel target
    while IFS= read -r -d '' rel; do
        rel="${rel#./}"
        target="$HOME/$rel"
        if [[ -e "$target" || -L "$target" ]] && [[ "$(readlink -f "$target")" != "$DOTFILES/$pkg/$rel" ]]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
            mv "$target" "$BACKUP_DIR/$rel"
            echo "backed up ~/$rel"
        fi
    done < <(cd "$DOTFILES/$pkg" && find . -type f -print0)
}

link_dotfiles() {
    log "Linking dotfiles with stow"
    for pkg in "${STOW_PACKAGES[@]}"; do
        backup_conflicts "$pkg"
        # --no-folding keeps real directories in ~/.config, so files wallust
        # generates (colors.conf, lock.sh, dunstrc...) never land in the repo.
        stow --no-folding --restow -d "$DOTFILES" -t "$HOME" "$pkg"
    done
    [[ -d "$BACKUP_DIR" ]] && log "Previous files saved in $BACKUP_DIR"
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null
}

install_udev_rules() {
    log "Installing udev rule for monitor hotplug"
    sudo cp "$DOTFILES/system/systemd/monitor-hotplug@.service" /etc/systemd/system/
    sed "s/hotplug@@USER@/hotplug@$USER/" "$DOTFILES/system/udev/95-monitor-hotplug.rules" \
        | sudo tee /etc/udev/rules.d/95-monitor-hotplug.rules >/dev/null
    sudo systemctl daemon-reload
    sudo udevadm control --reload
}

enable_user_services() {
    log "Enabling Bluetooth audio auto-switch"
    systemctl --user daemon-reload
    systemctl --user enable --now bt-audio-autoswitch.service
}

# Dark mode for GTK4/libadwaita and Electron/Chromium apps (they read the
# portal setting, not settings.ini), and the wallust-recolored GTK theme.
set_theme() {
    log "Building the wallust GTK theme and enabling dark mode"
    "$DOTFILES/bin/.local/bin/gtk-theme-wallust"
    # GTK settings.ini, gsettings and Burp, for the current light/dark mode
    "$DOTFILES/bin/.local/bin/theme-mode" apply
}

sync_login_screen() {
    log "Matching the LightDM login screen to the desktop"
    "$DOTFILES/bin/.local/bin/sync-lightdm" "$DEFAULT_WALLPAPER"
}

generate_colors() {
    log "Generating colors from the default wallpaper with wallust"
    mkdir -p "$HOME/Pictures/sc" "$HOME/.cache/wallust"
    "$HOME/.cargo/bin/wallust" run -s -p "$("$DOTFILES/bin/.local/bin/theme-mode")16" "$DEFAULT_WALLPAPER"
    chmod +x "$HOME/.config/i3/scripts/lock.sh"
}

# Download a release asset and check it against the release's checksum file.
fetch_verified() {
    local repo=$1 tag=$2 asset=$3 sums=$4 dir=$5
    curl -fsSLo "$dir/$asset" "https://github.com/$repo/releases/download/$tag/$asset"
    curl -fsSLo "$dir/$sums" "https://github.com/$repo/releases/download/$tag/$sums"
    (cd "$dir" && grep " $asset\$" "$sums" | sha256sum -c -)
}

# Notion Electron (unofficial Notion client) from its GitHub release RPM.
# Unsigned, so the pinned sha256 is the only check; dnf needs --nogpgcheck.
install_notion() {
    [[ "$(rpm -q --qf '%{VERSION}' notion-electron 2>/dev/null)" == "$NOTION_ELECTRON_VERSION" ]] && return
    log "Installing Notion Electron $NOTION_ELECTRON_VERSION"
    local tmp rpm="Notion_Electron-${NOTION_ELECTRON_VERSION}-x86_64.rpm"
    tmp="$(mktemp -d)"
    curl -fsSLo "$tmp/$rpm" \
        "https://github.com/anechunaev/notion-electron/releases/download/v$NOTION_ELECTRON_VERSION/$rpm"
    echo "$NOTION_ELECTRON_SHA256  $tmp/$rpm" | sha256sum -c -
    sudo dnf install -y --nogpgcheck "$tmp/$rpm"
    rm -rf "$tmp"
}

install_ai_tools() {
    local tmp
    tmp="$(mktemp -d)"
    mkdir -p "$HOME/.local/bin"

    if ! command -v claude >/dev/null; then
        log "Installing Claude Code"
        curl -fsSL https://claude.ai/install.sh | bash
    fi

    if [[ "$(engram version 2>/dev/null)" != "engram $ENGRAM_VERSION" ]]; then
        log "Installing engram $ENGRAM_VERSION"
        fetch_verified Gentleman-Programming/engram "v$ENGRAM_VERSION" \
            "engram_${ENGRAM_VERSION}_linux_amd64.tar.gz" checksums.txt "$tmp"
        tar -xzf "$tmp/engram_${ENGRAM_VERSION}_linux_amd64.tar.gz" -C "$tmp" engram
        install -m755 "$tmp/engram" "$HOME/.local/bin/engram"
    fi

    if ! codewhale --version 2>/dev/null | grep -q "^codewhale $CODEWHALE_VERSION "; then
        log "Installing Codewhale $CODEWHALE_VERSION"
        fetch_verified codewhale-hq/Codewhale "v$CODEWHALE_VERSION" \
            codewhale-linux-x64.tar.gz codewhale-artifacts-sha256.txt "$tmp"
        tar -xzf "$tmp/codewhale-linux-x64.tar.gz" -C "$tmp"
        install -m755 "$tmp/codewhale-linux-x64/codewhale" "$tmp/codewhale-linux-x64/codew" "$HOME/.local/bin/"
    fi
    rm -rf "$tmp"
}

# Codewhale rejects a symlinked config.toml, so it is copied instead of stowed.
configure_ai_tools() {
    command -v engram >/dev/null || return 0
    log "Connecting engram to Claude Code and Codewhale"
    command -v claude >/dev/null && engram setup claude-code
    if command -v codewhale >/dev/null; then
        mkdir -p "$HOME/.codewhale"
        [[ -e "$HOME/.codewhale/config.toml" ]] ||
            install -m600 "$DOTFILES/system/codewhale/config.toml" "$HOME/.codewhale/config.toml"
        codewhale mcp list 2>/dev/null | grep -q '^  - engram ' ||
            codewhale mcp add engram --command "$HOME/.local/bin/engram" --arg mcp --arg --tools=agent
    fi
}

(( INSTALL_PACKAGES )) && install_packages
install_gtk_theme
(( INSTALL_PACKAGES )) && install_ai_tools
(( INSTALL_PACKAGES )) && install_notion
link_dotfiles
configure_ai_tools
install_udev_rules
enable_user_services
generate_colors
set_theme
sync_login_screen

log "Done. Log out and pick i3 at the login screen (or press \$mod+Shift+r if already in i3)."
