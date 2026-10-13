#!/bin/bash
# Installs the Deck player (Spotify, https://github.com/jarilehtinen/deck).
# Source: ~/Projects/lab/deck (editable), binary: ~/.local/bin/deck, launch: Deck (⌘Space) and ⌘M.
# Needs Spotify Premium and the Client ID of your own Spotify app (~/.config/deck/config.toml), see Deck's README.
set -euo pipefail
src=$HOME/Projects/lab/deck

command -v cargo >/dev/null 2>&1 || sudo dnf install -y rust cargo gcc openssl-devel alsa-lib-devel
[[ -d $src/.git ]] || git clone https://github.com/jarilehtinen/deck "$src"
# Build the latest main (Linux support: MPRIS, state file, `deck ctl` and the launcher's JSON commands)
{ git -C "$src" checkout -q main && git -C "$src" pull -q --ff-only; } 2>/dev/null \
  || echo "Warning: couldn't update Deck's source in $src, building it as it is" >&2
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
