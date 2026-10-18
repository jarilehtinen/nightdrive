#!/bin/bash
# Installs the Deck player (Spotify, https://github.com/jarilehtinen/deck).
# Source: ~/.local/src/deck (another clone: DECK_SRC=~/path/to/deck ./install.sh), binary: ~/.local/bin/deck,
# launch: Deck (⌘Space) and Hyper+M (bin/deck-open). `nightdrive update` runs this again when Deck's source changes.
# Needs Spotify Premium and the Client ID of your own Spotify app (~/.config/deck/config.toml), see Deck's README.
set -euo pipefail
src=${DECK_SRC:-$HOME/.local/src/deck}

command -v cargo >/dev/null 2>&1 || sudo dnf install -y rust cargo gcc openssl-devel alsa-lib-devel
[[ -d $src/.git ]] || git clone https://github.com/jarilehtinen/deck "$src"
# Build the latest main (Linux support: MPRIS, state file, `deck ctl` and the launcher's JSON commands)
{ git -C "$src" checkout -q main && git -C "$src" pull -q --ff-only; } 2>/dev/null \
  || echo "Warning: couldn't update Deck's source in $src, building it as it is" >&2
cargo install --locked --path "$src" --root "$HOME/.local"      # --locked: librespot does not build with the latest dependencies

mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/scalable/apps"
install -m 644 "$src/assets/deck.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/deck.svg"
cat > "$HOME/.local/share/applications/deck.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Deck
Comment=Spotify player for the terminal
Exec=$HOME/.local/bin/deck-open
Icon=deck
Terminal=false
Categories=AudioVideo;Audio;Player;
StartupWMClass=deck
DESK
"$HOME/.config/fuzzel/sync-apps" >/dev/null 2>&1 || true     # visibility in the launcher
echo "Deck installed: ~/.local/bin/deck"
echo "Open it with Hyper+M (Caps Lock + M) or from the launcher."
