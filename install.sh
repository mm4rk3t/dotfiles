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

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_PACKAGES=(i3 polybar rofi alacritty picom wallust gtk zsh nvim wallpaper)
DEFAULT_WALLPAPER="$HOME/Pictures/wallpapers/Steins Gate Makise Kurisu Okabe Rintarou Gj Wallpaper.jpg"
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
    mapfile -t pkgs < <(read_list "$DOTFILES/packages/dnf.txt")
    sudo dnf install -y "${pkgs[@]}"

    log "Enabling COPR repos"
    while read -r repo pkg; do
        sudo dnf copr enable -y "$repo"
        # i3lock-color replaces the stock i3lock package
        sudo dnf install -y --allowerasing "$pkg"
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
}

generate_colors() {
    log "Generating colors from the default wallpaper with wallust"
    mkdir -p "$HOME/Pictures/sc" "$HOME/.cache/wallust"
    "$HOME/.cargo/bin/wallust" run -s "$DEFAULT_WALLPAPER"
    chmod +x "$HOME/.config/i3/scripts/lock.sh"
}

(( INSTALL_PACKAGES )) && install_packages
install_gtk_theme
link_dotfiles
generate_colors

log "Done. Log out and pick i3 at the login screen (or press \$mod+Shift+r if already in i3)."
