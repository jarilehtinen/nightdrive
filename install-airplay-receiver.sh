#!/bin/bash
# AirPlay Receiver: an iPhone, iPad or Mac mirrors its screen (or plays audio) to this computer, like macOS's AirPlay
# Receiver. UxPlay from Fedora; the video is decoded with FFmpeg from RPM Fusion (libavcodec-freeworld), because Fedora's
# own H.264 decoder (OpenH264) corrupts the picture on motion and the corruption stays until the next key frame.
# Runs as nightdrive-airplay.service (hypr/scripts/airplay-receiver). Run as a regular user; sudo asks for the password.
set -euo pipefail
repo=$(cd "$(dirname "$0")" && pwd)

rpm -q rpmfusion-free-release >/dev/null 2>&1 || \
  sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf install -y uxplay libavcodec-freeworld gstreamer1-plugin-libav
rm -rf "$HOME/.cache/gstreamer-1.0"   # GStreamer's plugin cache: the H.264/HEVC decoders show up at once
"$repo/config/hypr/scripts/airplay-receiver" enable
echo "AirPlay Receiver on: pick $("$repo/config/hypr/scripts/airplay-receiver" name) in Screen Mirroring on the iPhone"
