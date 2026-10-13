#!/bin/bash
# switch.sh on  → greetd (Nightdrive login screen) enabled from the next boot
# switch.sh off → back to the Plasma login screen
# Doesn't stop the running session. If the login screen doesn't come up: ctrl+alt+F3, log in and run `switch.sh off`, then `sudo reboot`.
set -euo pipefail
case "${1:-}" in
  on)  sudo systemctl disable plasmalogin.service 2>/dev/null || true
       sudo systemctl enable --force greetd.service
       echo "greetd enabled from the next boot." ;;
  off) sudo systemctl disable greetd.service 2>/dev/null || true
       sudo systemctl enable --force plasmalogin.service
       echo "plasmalogin re-enabled from the next boot." ;;
  *)   echo "Usage: $0 on|off" >&2; exit 1 ;;
esac
systemctl status display-manager.service --no-pager 2>/dev/null | head -2 || true
readlink /etc/systemd/system/display-manager.service
