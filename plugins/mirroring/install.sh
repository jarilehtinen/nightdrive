#!/bin/bash
# Installs doubletake (AirPlay screen mirroring to an Apple TV or an AirPlay TV, https://github.com/omarroth/doubletake):
# Settings › Display › Screen Mirroring in the launcher and the top bar's display menu. hyprland.lua starts its daemon
# (`doubletake -daemonize`), the menus talk to it with doubletake-ctl (bin/mirroring). `nightdrive update` runs this again
# when ref below changes.
# Source: ~/.local/src/doubletake at a tested commit (another one: DOUBLETAKE_REF=<commit or branch> ./install.sh),
# binaries: ~/.local/bin/doubletake and doubletake-ctl.
# Video is encoded with OpenH264 (Fedora's openh264 repo): Asahi has no hardware encoder, and x264 isn't in Fedora.
set -euo pipefail
src=$HOME/.local/src/doubletake
ref=${DOUBLETAKE_REF:-5e2f1cb}   # tested with an Apple TV 4K (2021) on 2026-10-15

# gst-launch-1.0 (gstreamer1), pipewiresrc (pipewire-gstreamer), h264parse and rtponviftimestamp (plugins-bad-free),
# pactl for the sound (pulseaudio-utils); gstreamer1-plugin-openh264 comes from the fedora-cisco-openh264 repo (on by default)
sudo dnf install -y golang git gstreamer1 pipewire-gstreamer gstreamer1-plugins-good gstreamer1-plugins-bad-free gstreamer1-plugin-openh264 pulseaudio-utils
[[ -d $src/.git ]] || git clone -q https://github.com/omarroth/doubletake "$src"
git -C "$src" fetch -q origin 2>/dev/null || echo "Warning: couldn't fetch doubletake's source, building $src as it is" >&2
git -C "$src" checkout -q "$ref"
mkdir -p "$HOME/.local/bin"
# Go's module and build caches under ~/.cache instead of ~/go
export GOPATH=$HOME/.cache/go GOCACHE=$HOME/.cache/go-build
(cd "$src" && go build -o "$HOME/.local/bin/doubletake" ./cmd/doubletake && go build -o "$HOME/.local/bin/doubletake-ctl" ./cmd/doubletake-ctl)
echo "doubletake installed: ~/.local/bin/doubletake"
echo "Use it in Settings › Display › Screen Mirroring."
echo "Its daemon starts at login."
