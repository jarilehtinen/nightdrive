#!/bin/bash
# Makes background.jpg, the login screen's background (LoginView.qml) and the boot splash's (splash/images.sh): the
# Nightdrive wallpaper darkened most in the middle, where the text is, so its colours stay at the edges. Drawn here at
# 16 bits rather than as a gradient in QML, which showed rings (8-bit steps) in the dark middle; a touch of noise keeps
# them out of the 8-bit file too. Run again after changing the wallpaper or the darkening.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
src=$here/../../wallpapers/nightdrive.jpg
size=$(magick identify -format %wx%h "$src")
# From 75 % in the middle to 25 % at the corners, of a deep blue-black
magick "$src" -depth 16 \( -size "$size" radial-gradient:'rgba(8,8,14,0.75)-rgba(8,8,14,0.25)' \) -composite \
  -attenuate 0.3 +noise Uniform -depth 8 -quality 94 "$here/background.jpg"
