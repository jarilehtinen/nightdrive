#!/bin/bash
# Installs greetd and the login screen files into /etc/greetd. Does NOT switch the login screen (that's done with: switch.sh on).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

sudo dnf install -y greetd greetd-selinux
[[ -f /etc/greetd/config.toml && ! -f /etc/greetd/config.toml.orig ]] && sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.orig
sudo install -d -m 0755 /etc/greetd /etc/greetd/greeter
sudo install -m 0644 "$here/config.toml" /etc/greetd/config.toml
sudo install -m 0644 "$here/hyprland-greeter.lua" /etc/greetd/hyprland-greeter.lua
sed "s/@USER@/${SUDO_USER:-$USER}/" "$here/shell.qml" | sudo install -m 0644 /dev/stdin /etc/greetd/greeter/shell.qml
sudo install -m 0644 "$here/background.jpg" /etc/greetd/greeter/background.jpg
sudo restorecon -R /etc/greetd 2>/dev/null || true
echo "Done. The login screen only switches with: $here/switch.sh on"
