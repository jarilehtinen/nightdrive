#!/bin/bash
# Installs greetd and the login screen files into /etc/greetd. Does NOT switch the login screen (that's done with: switch.sh on).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

sudo dnf install -y greetd greetd-selinux
[[ -f /etc/greetd/config.toml && ! -f /etc/greetd/config.toml.orig ]] && sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.orig
sudo install -d -m 0755 /etc/greetd /etc/greetd/greeter
sudo install -m 0644 "$here/config.toml" /etc/greetd/config.toml
# On a PC the scale is Hyprland's own pick. The keyboard is the layout Fedora's installer set on a PC, and on a Mac or a VM
# too unless it's Finnish, as install.sh writes for the session in hypr/local.lua (the file itself is the MacBook's):
# the password is typed with it
platform="$here/../hypr/scripts/platform"
machine=$("$platform" machine)
read -r kb_layout kb_variant _ <<<"$("$platform" keyboard)"
[[ $kb_layout =~ ^[a-z0-9_,-]+$ ]] || kb_layout=us
[[ ${kb_variant:-} =~ ^[a-z0-9_,-]*$ ]] || kb_variant=""
edits=()
[[ $machine == pc ]] && edits+=(-e 's/scale = 2\.0 })/scale = "auto" })/')
[[ $machine == pc || $kb_layout != fi ]] && \
  edits+=(-e "s/kb_layout = \"fi\", kb_variant = \"mac\"/kb_layout = \"$kb_layout\", kb_variant = \"${kb_variant:-}\"/")
sed "${edits[@]}" -e '' "$here/hyprland-greeter.lua" | sudo install -m 0644 /dev/stdin /etc/greetd/hyprland-greeter.lua
sed "s/@USER@/${SUDO_USER:-$USER}/" "$here/shell.qml" | sudo install -m 0644 /dev/stdin /etc/greetd/greeter/shell.qml
sudo install -m 0644 "$here/background.jpg" /etc/greetd/greeter/background.jpg
sudo restorecon -R /etc/greetd 2>/dev/null || true
echo "Done. The login screen only switches with: $here/switch.sh on"
