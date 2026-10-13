#!/bin/bash
# Symlinks the config/ directories into ~/.config and copies the fonts.
# An existing directory is moved to <name>.bak-<timestamp>. Safe to re-run.
set -euo pipefail
repo=$(cd "$(dirname "$0")" && pwd)

link() {
  local src=$1 dst=$2
  if [[ -L $dst && $(readlink -f "$dst") == $(readlink -f "$src") ]]; then echo "ok          $dst"; return; fi
  if [[ -e $dst || -L $dst ]]; then mv "$dst" "$dst.bak-$(date +%s)"; fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "linked      $dst -> $src"
}

for d in hypr topbar mako fuzzel kitty quickshell screensaver; do
  link "$repo/config/$d" "$HOME/.config/$d"
done
# The top bar used to be Waybar (config/waybar): drop its old link
[[ -L $HOME/.config/waybar && ! -e $HOME/.config/waybar ]] && rm "$HOME/.config/waybar" && echo "removed     $HOME/.config/waybar (old link)"
link "$repo/config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"   # Tokyo Night colours for libadwaita apps (Nautilus)
link "$repo/config/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
link "$repo/config/fontconfig/conf.d/10-nerd-font-symbols.conf" "$HOME/.config/fontconfig/conf.d/10-nerd-font-symbols.conf"

# EasyEffects (headphone EQ): presets as links, settings as a copy (KConfig would replace a link with a regular file)
mkdir -p "$HOME/.local/share/easyeffects/output" "$HOME/.config/easyeffects/db"
for f in "$repo"/config/easyeffects/output/*.json; do link "$f" "$HOME/.local/share/easyeffects/output/$(basename "$f")"; done
cp -n "$repo/config/easyeffects/db/easyeffectsrc" "$HOME/.config/easyeffects/db/easyeffectsrc"

link "$repo/config/wireplumber/wireplumber.conf.d/51-bt-no-headset-autoswitch.conf" "$HOME/.config/wireplumber/wireplumber.conf.d/51-bt-no-headset-autoswitch.conf"   # don't make the BT headset mic the default

link "$repo/config/alsa/asoundrc" "$HOME/.config/alsa/asoundrc"   # macbook_mic alias for dictation (voxtype)

# Session target: brings up graphical-session.target, which xdg-desktop-portal needs (started by hyprland.lua)
link "$repo/config/systemd/user/nightdrive-session.target" "$HOME/.config/systemd/user/nightdrive-session.target"
# Update check: every 6 h a fetch, and a notification when new commits are waiting (nightdrive update check)
for u in nightdrive-update-check.service nightdrive-update-check.timer; do link "$repo/config/systemd/user/$u" "$HOME/.config/systemd/user/$u"; done
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now nightdrive-update-check.timer 2>/dev/null || true

# The nightdrive command (bin/nightdrive)
mkdir -p "$HOME/.local/bin"
for f in "$repo"/bin/*; do link "$f" "$HOME/.local/bin/$(basename "$f")"; done

link "$repo/wallpapers" "$HOME/.local/share/wallpapers"   # wallpapers (chosen via: launcher › Settings › Background, hypr/scripts/wallpaper)

# Bash: simple prompt (Fedora's ~/.bashrc sources ~/.bashrc.d/*)
mkdir -p "$HOME/.bashrc.d"
for f in "$repo"/config/bash/*.sh; do link "$f" "$HOME/.bashrc.d/$(basename "$f")"; done

# Voxtype (speech to text, F5): config. The binaries ~/.local/bin/voxtype{,-onnx} and models ~/.local/share/voxtype/models are installed by hand (see docs/dictation.md).
mkdir -p "$HOME/.config/voxtype"
link "$repo/config/voxtype/config.toml" "$HOME/.config/voxtype/config.toml"
mkdir -p "$HOME/.local/share/voxtype/quickshell"
link "$repo/config/voxtype/OsdSurface.qml" "$HOME/.local/share/voxtype/quickshell/OsdSurface.qml"   # modified OSD (top centre, no dimming)
for f in listening.wav done.wav; do link "$repo/config/voxtype/$f" "$HOME/.local/share/voxtype/quickshell/$f"; done   # its sound cues (found next to it)

# Firefox: userChrome.css (tabs below the address bar) and user.js (enables userChrome.css) into the default profile
for p in "$HOME"/.config/mozilla/firefox/*.default-release; do
  [[ -d $p ]] || continue
  mkdir -p "$p/chrome"
  link "$repo/config/firefox/userChrome.css" "$p/chrome/userChrome.css"
  link "$repo/config/firefox/userContent.css" "$p/chrome/userContent.css"
  link "$repo/config/firefox/user.js" "$p/user.js"
done

# Thunderbird: Jokela Night userChrome.css (Lucide icons are read straight from the repo's icons/ directory), user.js
# and the folder-pane toggle button add-on. The toolbar button order lives in xulstore.json (see docs/thunderbird.md).
for p in "$HOME"/.config/thunderbird/*.default-release; do
  [[ -d $p ]] || continue
  mkdir -p "$p/chrome" "$p/extensions"
  link "$repo/config/thunderbird/userChrome.css" "$p/chrome/userChrome.css"
  link "$repo/config/thunderbird/userContent.css" "$p/chrome/userContent.css"
  link "$repo/config/thunderbird/user.js" "$p/user.js"
  sed "s|@DIR@|$repo/config/thunderbird|" "$repo/config/thunderbird/icons.css.in" > "$p/chrome/nightdrive-icons.css"
  xpi="$p/extensions/folderpane-toggle@jokela-night.xpi"
  rm -f "$xpi"
  (cd "$repo/config/thunderbird/folderpane-toggle" && zip -qj "$xpi" manifest.json background.js sidebar.svg)
  echo "built       $xpi"
done

mkdir -p "$HOME/.local/share/fonts"
cp -n "$repo"/fonts/*.ttf "$HOME/.local/share/fonts/"
fc-cache -f
