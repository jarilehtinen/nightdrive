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

for d in hypr topbar fuzzel kitty quickshell screensaver; do
  link "$repo/config/$d" "$HOME/.config/$d"
done
# Waybar drew the top bar until 13.10.2026; its config is gone from the repo (a leftover config/waybar only holds
# the old generated bar.css and your local.css), so the link goes
[[ -L $HOME/.config/waybar && $(readlink "$HOME/.config/waybar") == "$repo/config/waybar" ]] && rm "$HOME/.config/waybar" && echo "removed     $HOME/.config/waybar"
# The top bar used to be Waybar (config/waybar): drop its old link
[[ -L $HOME/.config/waybar && ! -e $HOME/.config/waybar ]] && rm "$HOME/.config/waybar" && echo "removed     $HOME/.config/waybar (old link)"
# Mako showed the notifications until 14.10.2026; Quickshell does now (quickshell/Notifs.qml). Its old link goes, and the
# unit is masked: D-Bus activation would start mako for the first notification and take the name from Quickshell.
[[ -L $HOME/.config/mako && ! -e $HOME/.config/mako ]] && rm "$HOME/.config/mako" && echo "removed     $HOME/.config/mako (old link)"
systemctl --user mask --now mako.service >/dev/null 2>&1 || true
# The share window (Screen Mirroring, Cast, video calls): xdg-desktop-portal-hyprland runs our picker (hypr/scripts/share-picker,
# quickshell/SharePicker.qml). Written here: the path must be absolute, and the file is git-ignored. Read when xdph starts.
xdph="$repo/config/hypr/xdph.conf"
want="screencopy {
    custom_picker_binary = $HOME/.config/hypr/scripts/share-picker
}"
if [[ $(cat "$xdph" 2>/dev/null) != "$want" ]]; then
  printf '%s\n' "$want" > "$xdph"; echo "wrote       $xdph"
  systemctl --user try-restart xdg-desktop-portal-hyprland >/dev/null 2>&1 || true
fi
link "$repo/config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"   # Tokyo Night colours for libadwaita apps (Nautilus)
link "$repo/config/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
# Apostrophe is a Flatpak: it reads its own config dir (install.sh lets the sandbox read config/gtk-4.0)
link "$repo/config/gtk-4.0/apostrophe.css" "$HOME/.var/app/org.gnome.gitlab.somas.Apostrophe/config/gtk-4.0/gtk.css"
link "$repo/config/fontconfig/conf.d/10-nerd-font-symbols.conf" "$HOME/.config/fontconfig/conf.d/10-nerd-font-symbols.conf"

# EasyEffects (headphone EQ): presets as links, settings as a copy (KConfig would replace a link with a regular file)
mkdir -p "$HOME/.local/share/easyeffects/output" "$HOME/.config/easyeffects/db"
for f in "$repo"/config/easyeffects/output/*.json; do link "$f" "$HOME/.local/share/easyeffects/output/$(basename "$f")"; done
cp -n "$repo/config/easyeffects/db/easyeffectsrc" "$HOME/.config/easyeffects/db/easyeffectsrc"

link "$repo/config/wireplumber/wireplumber.conf.d/51-bt-no-headset-autoswitch.conf" "$HOME/.config/wireplumber/wireplumber.conf.d/51-bt-no-headset-autoswitch.conf"   # don't make the BT headset mic the default

link "$repo/config/nautilus-python/localsend.py" "$HOME/.local/share/nautilus-python/extensions/localsend.py"   # Files › Send with LocalSend (shown while the plugin is on)
link "$repo/config/applications/nm-connection-editor.desktop" "$HOME/.local/share/applications/nm-connection-editor.desktop"   # Fedora ships none
# macbook_mic alias for dictation (voxtype): the MacBook's mic on Apple Silicon, the default mic elsewhere
if [[ $("$repo/config/hypr/scripts/platform" name) == asahi ]]; then asound=asoundrc; else asound=asoundrc.generic; fi
link "$repo/config/alsa/$asound" "$HOME/.config/alsa/asoundrc"
# Mac text keys plugin (install-keyd.sh): keyd-application-mapper's per-app keys
[[ -f /etc/keyd/default.conf ]] && link "$repo/config/keyd/app.conf" "$HOME/.config/keyd/app.conf"

# Session target: brings up graphical-session.target, which xdg-desktop-portal needs (started by hyprland.lua)
link "$repo/config/systemd/user/nightdrive-session.target" "$HOME/.config/systemd/user/nightdrive-session.target"
# Update check: every 6 h a fetch, and a notification when new commits are waiting (nightdrive update check).
# Snippets, LocalSend and AirPlay Receiver: linked only, started when turned on (hypr/scripts/snippets enable, localsend
# enable, airplay-receiver enable)
for u in nightdrive-update-check.service nightdrive-update-check.timer nightdrive-snippets.service nightdrive-localsend.service nightdrive-airplay.service; do link "$repo/config/systemd/user/$u" "$HOME/.config/systemd/user/$u"; done
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now nightdrive-update-check.timer 2>/dev/null || true

# The nightdrive command (bin/nightdrive)
mkdir -p "$HOME/.local/bin"
for f in "$repo"/bin/*; do link "$f" "$HOME/.local/bin/$(basename "$f")"; done

link "$repo/wallpapers" "$HOME/.local/share/wallpapers"   # wallpapers (chosen via: launcher › Settings › Background, hypr/scripts/wallpaper)
link "$repo/sounds" "$HOME/.local/share/nightdrive/sounds"   # notification sounds (launcher › Settings › Notifications, hypr/scripts/sounds)
# Fedora Asahi's steam package installs a steam locomotive as the hicolor "steam" icon (the launcher and the bar fall back
# to hicolor): Papirus's Steam logo goes in front of it in the user's hicolor
papirus_steam=/usr/share/icons/Papirus/32x32/apps/steam.svg
[[ -f $papirus_steam ]] && link "$papirus_steam" "$HOME/.local/share/icons/hicolor/scalable/apps/steam.svg"

# Bash: prompt, history, ble.sh (Fedora's ~/.bashrc sources ~/.bashrc.d/*)
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
cp -u "$repo"/fonts/*.ttf "$HOME/.local/share/fonts/"   # -u: an updated font in the repo replaces the old one
fc-cache -f
