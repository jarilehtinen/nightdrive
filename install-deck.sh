#!/bin/bash
# Installs the Deck player (Spotify, https://github.com/jarilehtinen/deck).
# Source: ~/Projects/lab/deck (editable), binary: ~/.local/bin/deck, launch: Deck (⌘Space) and ⌘M.
# Needs Spotify Premium and the Client ID of your own Spotify app (~/.config/deck/config.toml), see Deck's README.
set -euo pipefail
src=$HOME/Projects/lab/deck

command -v cargo >/dev/null 2>&1 || sudo dnf install -y rust cargo gcc openssl-devel alsa-lib-devel
[[ -d $src/.git ]] || git clone https://github.com/jarilehtinen/deck "$src"
# Linux support (MPRIS, state file, `deck ctl`) lives on the linux-mpris branch (on GitHub, not yet in main)
{ git -C "$src" fetch -q origin linux-mpris && git -C "$src" checkout -q linux-mpris; } 2>/dev/null \
  || echo "Warning: Deck's linux-mpris branch not found, building the default branch (no top bar / launcher integration)" >&2
cargo install --locked --path "$src" --root "$HOME/.local"      # --locked: librespot does not build with the latest dependencies

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/deck.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Deck
Comment=Spotify player for the terminal
Exec=$HOME/.config/hypr/scripts/deck-open
Icon=music
Terminal=false
Categories=AudioVideo;Audio;Player;
StartupWMClass=deck
DESK
"$HOME/.config/fuzzel/sync-apps" >/dev/null 2>&1 || true     # icon and visibility in the launcher
echo "Deck installed: $HOME/.local/bin/deck  (launch: ⌘M or from the launcher)"
