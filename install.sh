#!/bin/bash
# Sets up this environment on a fresh Fedora Asahi Remix 44 install (aarch64, MacBook).
#   ./install.sh               asks which optional parts to install (1Password, Deck, web apps…, plugins.txt), then runs
#                              unattended: updates the system, installs packages, fonts, the notch setting, links the
#                              configs, installs the Nightdrive login screen (greetd, password only, active from the next
#                              boot) and the chosen parts. Home Assistant, if chosen, asks for its address at the end.
#   ./install.sh --with deck,1password   these parts on top of the defaults, without asking (ids: --dry-run lists them)
#   ./install.sh --without youtube       the defaults without these, without asking (--with and --without combine)
#   ./install.sh --all / --none / --defaults   every optional part / none / the defaults (Default on in plugins.txt)
#   ./install.sh --dry-run     shows the optional parts and which would be installed, and stops
#   ./install.sh --no-greeter  keeps the distribution's own login screen (pick "Hyprland" there)
#   ./install.sh --keep-apps   keeps the KDE apps and system services that are otherwise removed (packages-remove*.txt)
#   ./install.sh --no-kde      removes Plasma entirely (needs the greeter); experimental, see config/greeter/
#   ./install.sh --vm          for trying it on a non-Asahi machine (e.g. a Fedora 44 VM): skips the notch setting
# Without a terminal (or with any of --with/--without/--all/--none/--defaults) nothing is asked. What was skipped can be
# added later: launcher › Install › Plugins, or `nightdrive plugins install ID`.
# Run as a regular user; sudo asks for the password once at the start.
set -euo pipefail
repo=$(cd "$(dirname "$0")" && pwd)
debloat=1; vm=0; greeter=1; nokde=0; dry=0
base=""; with=""; without=""     # base: all | none | defaults, "" = ask
usage() { sed -n '3,19p' "$0" | sed 's/^# \{0,1\}//'; }
while (( $# )); do
  case $1 in
    --debloat) ;;              # the default now; still accepted
    --keep-apps) debloat=0 ;;
    --vm) vm=1 ;;
    --greeter) ;;              # the default now; still accepted
    --no-greeter) greeter=0 ;;
    --no-kde) nokde=1 ;;
    --all) base=all ;;
    --none) base=none ;;
    --defaults) base=defaults ;;
    --with=*) with+=,${1#*=} ;;
    --without=*) without+=,${1#*=} ;;
    --with|--without) [[ -n ${2:-} ]] || { echo "$1 needs a list of ids, e.g. $1 deck,youtube" >&2; exit 2; }
                      if [[ $1 == --with ]]; then with+=,$2; else without+=,$2; fi; shift ;;
    --dry-run) dry=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1 (see ./install.sh --help)" >&2; exit 2 ;;
  esac
  shift
done
(( nokde && !greeter )) && { echo "--no-kde removes the KDE login screen, so it can't be combined with --no-greeter" >&2; exit 2; }
pkgs() { grep -vE '^\s*(#|$)' "$1" | tr '\n' ' '; }

# --- Optional parts (plugins.txt): chosen now, installed at the end ---
ids=(); names=(); descs=(); on=()
while IFS='|' read -r id name _ desc def _; do
  ids+=("$id"); names+=("$name"); descs+=("$desc"); on+=("$([[ $def == on ]] && echo 1 || echo 0)")
done < <(grep -vE '^\s*(#|$)' "$repo/plugins.txt")
case $base in
  all) on=("${on[@]/*/1}") ;;
  none) on=("${on[@]/*/0}") ;;
esac
# --with/--without: ids (or names) separated by commas
toggle_listed() {  # toggle_listed LIST 0|1
  local list w i found
  IFS=, read -ra list <<<"$1"
  for w in "${list[@]}"; do
    [[ -n $w ]] || continue
    found=0
    for i in "${!ids[@]}"; do
      [[ ${ids[i],,} == "${w,,}" || ${names[i],,} == "${w,,}" ]] && { on[i]=$2; found=1; }
    done
    (( found )) || { echo "unknown optional part: $w (available: ${ids[*]})" >&2; exit 2; }
  done
}
toggle_listed "$with" 1
toggle_listed "$without" 0
show_parts() {
  local i w=$(( $(tput cols 2>/dev/null || echo 100) - 28 ))
  for i in "${!ids[@]}"; do
    printf '  %2d [%s] %-17s %s\n' $((i + 1)) "$([[ ${on[i]} == 1 ]] && echo x || echo ' ')" "${names[i]}" "${descs[i]:0:w}"
  done
}
if [[ -z $base$with$without && -t 0 ]]; then
  echo "Optional parts. Everything else is the same on every install; these can also be added later (launcher ›"
  echo "Install › Plugins). Type numbers to tick or untick (e.g. 2 5), a = all, n = none, Enter installs the ticked ones."
  while true; do
    echo; show_parts; echo
    read -rp "Toggle (Enter to continue): " ans
    [[ -z $ans ]] && break
    for a in $ans; do
      case $a in
        a) on=("${on[@]/*/1}") ;;
        n) on=("${on[@]/*/0}") ;;
        *) if [[ $a =~ ^[0-9]+$ ]] && (( a >= 1 && a <= ${#ids[@]} )); then on[a-1]=$(( 1 - on[a-1] ))
           else echo "  not a number from the list: $a"; fi ;;
      esac
    done
  done
fi
chosen=(); for i in "${!ids[@]}"; do [[ ${on[i]} == 1 ]] && chosen+=("${ids[i]}"); done
if (( dry )); then show_parts; echo; echo "Would install: ${chosen[*]:-(no optional parts)}"; exit 0; fi
echo "Optional parts: ${chosen[*]:-none}"
has() { [[ " ${chosen[*]} " == *" $1 "* ]]; }

# sudo once: the system update and the compiling take long, and the password asked again halfway would stop the
# install. Kept alive until the script exits.
sudo -v
while sleep 50; do kill -0 $$ 2>/dev/null || exit; sudo -n -v 2>/dev/null; done &
keepalive=$!
tmp=$(mktemp -d); trap 'kill $keepalive 2>/dev/null; rm -rf "$tmp"' EXIT   # downloads (Nerd Fonts)

echo "==> System update (a fresh install from an older image would otherwise get a half-updated KDE: file conflicts)"
sudo dnf upgrade --refresh -y

echo "==> Hyprland (COPR arcaneon/arcos, Hyprland's own packages only)"
# Fedora's own repos have no Hyprland for aarch64. includepkgs keeps the COPR from replacing other packages.
sudo dnf copr enable -y arcaneon/arcos
repo_file=$(ls /etc/yum.repos.d/*arcaneon*arcos*.repo)
grep -q '^includepkgs=' "$repo_file" || \
  sudo sed -i '/^\[copr:/a includepkgs=hypr*,aquamarine,xdg-desktop-portal-hyprland,uwsm,glaze' "$repo_file"
sudo dnf install -y $(pkgs "$repo/packages-hyprland.txt")

echo "==> Fedora packages"
sudo dnf install -y $(pkgs "$repo/packages.txt")
# install leaves a package that KDE already pulled in marked as a dependency, and the removals below would take it along
sudo dnf mark user $(pkgs "$repo/packages.txt") >/dev/null

if (( vm )); then
  echo "==> Skipping the notch setting (--vm)"
  if [[ -e $repo/config/hypr/local.lua ]]; then
    echo "    config/hypr/local.lua already exists, leaving it as is (delete it to regenerate the VM settings)"
  else
    cat > "$repo/config/hypr/local.lua" <<'LUA'
-- Generated by: ./install.sh --vm (virtual machine). Machine-specific; delete this file to restore the MacBook settings.
NIGHTDRIVE = { corners = false }                       -- the rounded-corner shader is tuned for the 3024×1964 display (scale 2.0)
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 2.0 })   -- Parallels "Best for Retina display"; "Scaled": launcher › Settings › Display
hl.config({ cursor = { no_hardware_cursors = true } })                              -- in VMs the hardware cursor is often invisible
LUA
  fi
else
  echo "==> Notch: the display uses the full top edge (appledrm.show_notch=1, requires a reboot)"
  sudo grubby --update-kernel=ALL --args="appledrm.show_notch=1"
fi

echo "==> Nerd Fonts symbols (icons for the top bar and menus)"
fonts=$HOME/.local/share/fonts; mkdir -p "$fonts"
if ! ls "$fonts"/SymbolsNerdFont-Regular.ttf >/dev/null 2>&1; then
  curl -fsSL -o "$tmp/nf.zip" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/NerdFontsSymbolsOnly.zip
  unzip -o -q "$tmp/nf.zip" -d "$tmp/nf" && cp "$tmp"/nf/*.ttf "$fonts"/
fi
echo "==> Six Caps (the clock screensaver's font, Google Fonts)"
if ! ls "$fonts"/SixCaps.ttf >/dev/null 2>&1; then
  curl -fsSL -o "$fonts/SixCaps.ttf" https://raw.githubusercontent.com/google/fonts/main/ofl/sixcaps/SixCaps.ttf && fc-cache -f "$fonts"
fi

echo "==> Configs (links into ~/.config, fonts)"
"$repo/link.sh"

echo "==> ble.sh (bash: history suggestions while typing, syntax colours; config/bash/00-blesh.sh loads it)"
blesh_src=$HOME/.local/src/ble.sh
[[ -d $blesh_src/.git ]] || git clone -q --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git "$blesh_src"
make -C "$blesh_src" -s install PREFIX="$HOME/.local"

echo "==> GTK: no KDE 1.7x text scaling, Papirus icons"
for v in 3.0 4.0; do
  f=$HOME/.config/gtk-$v/settings.ini
  [[ -f $f ]] || { mkdir -p "$(dirname "$f")"; printf '[Settings]\n' > "$f"; }
  for kv in 'gtk-xft-dpi=98304' 'gtk-icon-theme-name=Papirus-Dark' 'gtk-decoration-layout=:' 'gtk-cursor-theme-name=breeze_cursors' 'gtk-application-prefer-dark-theme=1'; do
    k=${kv%%=*}
    if grep -q "^$k=" "$f"; then sed -i "s|^$k=.*|$kv|" "$f"; else echo "$kv" >> "$f"; fi
  done
done
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
gsettings set org.gnome.desktop.wm.preferences button-layout ':' 2>/dev/null || true

echo "==> Flatpak apps (flatpaks.txt, from Flathub, per user)"
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
[[ -z $(pkgs "$repo/flatpaks.txt") ]] || flatpak install --user -y --noninteractive flathub $(pkgs "$repo/flatpaks.txt")

echo "==> Default apps: images open in Loupe (instead of the browser); Markdown in Apostrophe, if chosen (its installer)"
xdg-mime default org.gnome.Loupe.desktop image/png image/jpeg image/gif image/webp image/bmp image/tiff image/svg+xml image/avif image/heic

echo "==> Sleep hook (Wi-Fi and Bluetooth off during sleep, battery drain logging)"
sudo install -m 0755 "$repo/config/system/nightdrive-sleep" /usr/lib/systemd/system-sleep/nightdrive-sleep

echo "==> dnf hook: a part installed or removed with dnf shows up or goes away at once (config/system/nightdrive.actions)"
sudo install -Dm644 "$repo/config/system/nightdrive.actions" /etc/dnf/libdnf5-plugins/actions.d/nightdrive.actions
[[ -e /var/lib/nightdrive/dnf-changed ]] || sudo install -Dm644 /dev/null /var/lib/nightdrive/dnf-changed

echo "==> logind: F6 (KEY_SLEEP) is do not disturb, the power button opens the power dialog (config/hypr/bindings.lua)"
sudo install -Dm644 "$repo/config/system/logind-ignore-sleep-key.conf" /etc/systemd/logind.conf.d/50-ignore-sleep-key.conf
sudo install -Dm644 "$repo/config/system/logind-power-key.conf" /etc/systemd/logind.conf.d/50-power-key.conf
sudo systemctl kill -s HUP systemd-logind

if (( greeter )); then
  echo "==> Login screen (greetd + Quickshell); takes effect from the next boot"
  "$repo/config/greeter/install.sh"
  "$repo/config/greeter/switch.sh" on
fi

if (( debloat )); then
  echo "==> Removing unneeded apps and services (packages-remove.txt; keep them with --keep-apps)"
  # Packages that aren't installed are skipped. dnf also removes what only they needed, so packages.txt lists the
  # few things the scripts use that would otherwise go with them (ImageMagick, zenity).
  sudo dnf remove -y $(pkgs "$repo/packages-remove.txt") 'libreoffice-*'
  if (( !vm )); then
    echo "==> Removing other hardware's firmware and VM guest tools (packages-remove-asahi.txt)"
    sudo dnf remove -y $(pkgs "$repo/packages-remove-asahi.txt")
  fi
fi

# Last of the unattended part. One that fails doesn't stop the rest: it's listed at the end, and can be run again from
# the launcher (Install › Plugins) or with `nightdrive plugins install ID`.
failed=()
for id in "${chosen[@]}"; do
  "$repo/bin/nightdrive" plugins install "$id" || failed+=("$id")
done
"$repo/bin/nightdrive" plugins installed >/dev/null
"$repo/config/fuzzel/sync-apps"

if (( nokde )); then
  echo "==> Removing Plasma (experimental). Keeping the cursor theme, GTK fonts and power profiles."
  sudo dnf mark user breeze-cursor-theme google-noto-sans-fonts google-noto-sans-mono-fonts google-noto-serif-fonts tuned tuned-ppd vulkan-tools xdg-user-dirs
  sudo rm -f /etc/dnf/protected.d/plasma-desktop.conf
  # dnf shows a summary and asks for confirmation; fedora-asahi-remix-release-kde-desktop stays (it provides system-release)
  sudo dnf remove plasma-desktop plasma-workspace kwin kwin-common kscreen kscreenlocker powerdevil plasma-login-manager kcm-plasmalogin \
    kde-settings-plasmalogin kde-settings-plasma polkit-kde kf6-kwallet pam-kwallet ksshaskpass signon-kwallet-extension plasma-nm plasma-pa \
    plasma-systemsettings bluedevil kde-gtk-config plasma-integration plasma-lookandfeel-fedora \
    plasma-workspace-wallpapers kde-inotify-survey kde-settings-pulseaudio phonon-qt6-backend-vlc pinentry-qt xwaylandvideobridge
fi

echo
(( ${#failed[@]} )) && echo "Not installed (an error, see above): ${failed[*]}. Run again: nightdrive plugins install ID" && echo
echo "Done. Still to do by hand:"
if has tailscale; then
  echo '  sudo tailscale up                          # log in'
  echo '  sudo tailscale set --operator=$USER        # lets the top bar Tailscale click work without a password'
fi
has deck && echo "  Deck: needs Spotify Premium and the Client ID of your own Spotify app (~/.config/deck/config.toml), see Deck's README."
if has thunderbird; then
  echo "  Firefox and Thunderbird: open each once, then run ./link.sh again (it themes their profiles, which don't exist yet)."
else
  echo "  Firefox: open it once, then run ./link.sh again (it themes its profile, which doesn't exist yet)."
fi
has 1password && echo "  Firefox: the 1Password extension from addons.mozilla.org."
echo "  Optional parts you skipped: launcher › Install › Plugins, or \`nightdrive plugins\`."
if (( greeter )); then
  echo "  Reboot: the Nightdrive login screen starts Hyprland (if it breaks: ctrl+alt+F3, log in and run config/greeter/switch.sh off)."
else
  echo "  Reboot and pick \"Hyprland\" (not \"Hyprland (uwsm-managed)\") as the session at the login screen."
fi
(( vm )) || echo "  The notch setting also takes effect at the reboot."
