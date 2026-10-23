#!/bin/bash
# Mail's installer (plugin.conf): the packages, Mail among the apps and the sync. Without an account yet, Mail opens on its
# first start, which offers to set one up with Claude (`nightmail setup`, README.md › Setting up an account).
# Safe to run again: `nightmail enable` at the end of the setup does the same.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

sudo dnf install -y notmuch isync libsecret zenity python3

bin/nightmail enable
if [[ ! -f ~/.config/isyncrc || ! -f ~/.config/nightmail/account.conf ]] || ! notmuch config get database.path >/dev/null 2>&1; then
  # Nightdrive's own installer (install.sh) installs Mail on every machine: the setup waits for Mail's first start
  [[ -n ${NIGHTDRIVE_INSTALL:-} ]] && { echo "Mail is installed; its first start offers to set up your account."; exit 0; }
  cat <<MSG

Mail needs your email account first: Mail opens now and Claude can set it up with you (or: nightmail setup).
To do it yourself, the plugin's page has the steps (launcher › System › Install › Plugins › Mail, or $PWD/README.md).
MSG
  # Only on the desktop (not over ssh)
  [[ -n ${WAYLAND_DISPLAY:-} ]] && bin/nightmail
  exit 0
fi
echo "Mail is ready: nightmail opens it (or the launcher: Mail)."
