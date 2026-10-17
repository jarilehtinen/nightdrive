#!/bin/bash
# switch.sh on        → greetd (Nightdrive login screen) enabled from the next boot
# switch.sh autologin → greetd logs in at boot by itself, and the same login screen locks the session (lock.qml); one
#                       handover of the screen at boot instead of two. After logging out, the login screen is greetd's.
# switch.sh off       → back to the Plasma login screen
# Doesn't stop the running session. If the login screen doesn't come up: ctrl+alt+F3, log in and run `switch.sh off`, then `sudo reboot`.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
CONF=/etc/greetd/config.toml
PAM=/etc/pam.d/nightdrive-lock

greetd_on() {
  [[ -f $CONF ]] || { echo "greetd isn't installed: run $here/install.sh first" >&2; exit 1; }
  sudo systemctl disable plasmalogin.service 2>/dev/null || true
  sudo systemctl enable --force greetd.service
}
# The config without the autologin block (it's the last section when there); read before the file is rewritten
base_conf() { sed -e '/^# Autologin at boot/,$d' -e '/^\[initial_session\]/,$d' "$CONF" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'; }

case "${1:-}" in
  on)  greetd_on
       conf=$(base_conf)
       printf '%s\n' "$conf" | sudo install -m 0644 /dev/stdin "$CONF"
       echo "greetd enabled from the next boot." ;;
  autologin)
       # The lock at startup is started from ~/.config/greeter (link.sh) by hyprland.lua
       [[ -f $HOME/.config/greeter/lock.qml ]] || { echo "~/.config/greeter/lock.qml is missing: run link.sh first" >&2; exit 1; }
       greetd_on
       user=${SUDO_USER:-$USER}
       sudo install -m 0644 "$here/nightdrive-lock.pam" "$PAM"
       conf=$(base_conf)
       { printf '%s\n' "$conf"
         printf '\n# Autologin at boot (switch.sh autologin): the session starts locked (hypr/hyprland.lua, greeter/lock.qml)\n'
         printf '[initial_session]\ncommand = "env NIGHTDRIVE_LOCKED_START=1 start-hyprland"\nuser = "%s"\n' "$user"
       } | sudo install -m 0644 /dev/stdin "$CONF"
       sudo restorecon "$CONF" "$PAM" 2>/dev/null || true
       echo "greetd enabled from the next boot, logging in $user by itself; the session starts locked." ;;
  off) sudo systemctl disable greetd.service 2>/dev/null || true
       sudo systemctl enable --force plasmalogin.service
       echo "plasmalogin re-enabled from the next boot." ;;
  *)   echo "Usage: $0 on|autologin|off" >&2; exit 1 ;;
esac
systemctl status display-manager.service --no-pager 2>/dev/null | head -2 || true
readlink /etc/systemd/system/display-manager.service
