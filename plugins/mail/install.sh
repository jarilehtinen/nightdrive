#!/bin/bash
# Mail's installer (plugin.conf): the packages, then Mail among the apps and the sync once an account is set up (README.md
# › Setting up an account). Safe to run again: after setting up the account, run it again (or `nightmail enable`).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

sudo dnf install -y notmuch isync libsecret zenity python3

if [[ ! -f ~/.config/isyncrc || ! -f ~/.config/nightmail/account.conf ]] || ! notmuch config get database.path >/dev/null 2>&1; then
  cat <<MSG

Mail needs your account first: ~/.config/isyncrc (fetching), notmuch's setup (the index) and
~/.config/nightmail/account.conf (sending). The plugin's page explains each step (launcher › System › Install ›
Plugins › Mail, or $PWD/README.md), and Claude can follow it with you.
Then run this again, or: nightmail enable
MSG
  exit 0
fi
bin/nightmail enable
echo "Mail is ready: nightmail opens it (or the launcher: Mail)."
