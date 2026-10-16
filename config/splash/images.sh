#!/bin/bash
# images.sh DIR: draws the splash images into DIR, laid out as the login screen (config/greeter/shell.qml): its background
# with the same dimming, the title, and a spinner where the password field is.
# Made for SCREEN at device pixels (Plymouth's DeviceScale=1); on another screen size Plymouth scales the background
# and keeps the title and spinner at the same relative height.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=${1:?usage: images.sh DIR}
mkdir -p "$out"

SCREEN_W=3024; SCREEN_H=1964; SCALE=2           # MacBook Air 13" (M2), the Asahi screen the login screen was drawn on
BG=$here/../greeter/background.jpg
BG_COLOR='#1a1b26'; DIM=0.72                     # shell.qml: bg, and the Rectangle over the wallpaper
ACCENT='#e0bff2'; RING='#565f8966'               # shell.qml: accent; dim at 40 %
FONT=/usr/share/fonts/jetbrains-mono-fonts/JetBrainsMono-Light.otf
TITLE_PX=34; TITLE_SPACING=6                     # shell.qml: the title's pixelSize and letterSpacing
SPINNER_PX=36; SPINNER_STROKE=2.5                # in logical px, inside the 48 px tall password field
# Centres in logical px from the top, from shell.qml's Column centred on the screen: title (line 45) + 28 + field 48 + 28
# + message 20 = 169 high. The title's glyphs sit ~4 px below the centre of their line (JetBrains Mono's ascent 1.02,
# cap height 0.73, descent of g ~0.24).
TITLE_Y=433; FIELD_Y=503.5

px() { awk -v v="$1" -v s=$SCALE 'BEGIN { printf "%d", v * s + 0.5 }'; }

# Background: the wallpaper cropped to fill the screen (PreserveAspectCrop), under the dimming
magick "$BG" -resize "${SCREEN_W}x${SCREEN_H}^" -gravity center -extent "${SCREEN_W}x${SCREEN_H}" \
  \( +clone -fill "$BG_COLOR" -colorize 100 \) -compose blend -define compose:args=$(awk -v d=$DIM 'BEGIN{print d*100}') \
  -composite -depth 8 "$out/background-tile.png"

magick -background none -fill "$ACCENT" -font "$FONT" -pointsize "$(px $TITLE_PX)" -kerning "$(px $TITLE_SPACING)" \
  label:Nightdrive -trim +repage "$out/watermark.png"

d=$(px $SPINNER_PX); sw=$(px $SPINNER_STROKE); r=$(( (d - sw) / 2 - 1 )); c=$(( d / 2 ))
magick -size ${d}x${d} xc:none -fill none -strokewidth "$sw" -stroke "$RING" -draw "circle $c,$c $c,$((c - r))" \
  -stroke "$ACCENT" -draw "path 'M $c,$((c - r)) A $r,$r 0 0 1 $((c + r)),$c'" "$out/frame.png"
for i in $(seq 1 30); do
  f=$(printf '%04d' "$i")
  magick "$out/frame.png" -distort SRT $(( (i - 1) * 12 )) -depth 8 "$out/throbber-$f.png"
  cp "$out/throbber-$f.png" "$out/animation-$f.png"
done
rm "$out/frame.png"

# The two-step plugin's alignment is (screen - image) * a: work it out for the centres above
wh=$(magick identify -format %h "$out/watermark.png")
awk -v y="$(px $TITLE_Y)" -v h="$wh" -v H=$SCREEN_H 'BEGIN { printf "WatermarkVerticalAlignment=%.4f\n", (y - h/2) / (H - h) }'
awk -v y="$(px $FIELD_Y)" -v h="$d" -v H=$SCREEN_H 'BEGIN { printf "VerticalAlignment=%.4f\n", (y - h/2) / (H - h) }'
