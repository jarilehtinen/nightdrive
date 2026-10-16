#!/bin/bash
# Mac text keys (plugin keyd): ⌥⌫ deletes a word, ⌘⌫ to the start of the line (Files: to the trash, Thunderbird: the
# message), done by keyd as real key presses before Hyprland. Hyprland's own way (send_shortcut) sometimes loses a key's
# release and the app repeats the key (Hyprland #8385, #6407). keyd comes from a COPR (alternateved/keyd): it isn't in
# Fedora's own repos. Config: config/keyd (default.conf → /etc/keyd, app.conf → ~/.config/keyd for the per-app mapper).
# Emergency exit: Backspace + Escape + Enter together stops keyd. Off again: sudo systemctl disable --now keyd
set -euo pipefail
repo=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
sudo dnf copr enable -y alternateved/keyd
sudo dnf install -y keyd
sudo install -Dm644 "$repo/config/keyd/default.conf" /etc/keyd/default.conf
# keyd's virtual keyboard counts as the internal one: the trackpad's disable-while-typing keeps working
sudo install -Dm644 "$repo/config/keyd/local-overrides.quirks" /etc/libinput/local-overrides.quirks
sudo usermod -aG keyd "$USER"   # keyd-application-mapper talks to keyd's socket
sudo systemctl enable --now keyd
sudo keyd reload
mkdir -p ~/.config/keyd && ln -sfn "$repo/config/keyd/app.conf" ~/.config/keyd/app.conf
# Started for this session too (bindings.lua starts it from the next login, when the keyd group is in effect)
pgrep -f keyd-application-mapper >/dev/null || setsid sg keyd -c "keyd-application-mapper -d" </dev/null >/dev/null 2>&1 &
~/.local/bin/nightdrive plugins installed >/dev/null 2>&1 || true   # the desktop picks the plugin up (bindings.lua)
echo "Mac text keys are on. ⌘⌫ follows the app from the next login (keyd group)."
