#!/bin/bash
# images.sh DIR: draws the splash images into DIR: the login screen's background (greeter/background.jpg, already darkened
# by greeter/background.sh) and a spinner in the middle, where the login screen's logo then types itself in.
# Made for SCREEN at device pixels (Plymouth's DeviceScale=1); on another screen size Plymouth scales the background
# and keeps the spinner in the middle.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=${1:?usage: images.sh DIR}
mkdir -p "$out"

SCREEN_W=3024; SCREEN_H=1964; SCALE=2           # MacBook Air 13" (M2), the Asahi screen the login screen was drawn on
BG=$here/../greeter/background.jpg
ACCENT='#e0bff2'; RING='#565f8966'               # LoginView.qml: accent; dim at 40 %
SPINNER_PX=36; SPINNER_STROKE=2.5                # in logical px

px() { awk -v v="$1" -v s=$SCALE 'BEGIN { printf "%d", v * s + 0.5 }'; }

# Background: the login screen's, cropped to fill the screen (PreserveAspectCrop)
magick "$BG" -resize "${SCREEN_W}x${SCREEN_H}^" -gravity center -extent "${SCREEN_W}x${SCREEN_H}" -depth 8 "$out/background-tile.png"

d=$(px $SPINNER_PX); sw=$(px $SPINNER_STROKE); r=$(( (d - sw) / 2 - 1 )); c=$(( d / 2 ))
magick -size ${d}x${d} xc:none -fill none -strokewidth "$sw" -stroke "$RING" -draw "circle $c,$c $c,$((c - r))" \
  -stroke "$ACCENT" -draw "path 'M $c,$((c - r)) A $r,$r 0 0 1 $((c + r)),$c'" "$out/frame.png"
for i in $(seq 1 30); do
  f=$(printf '%04d' "$i")
  magick "$out/frame.png" -distort SRT $(( (i - 1) * 12 )) -depth 8 "$out/throbber-$f.png"
  cp "$out/throbber-$f.png" "$out/animation-$f.png"
done
rm "$out/frame.png"

