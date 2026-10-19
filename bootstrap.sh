#!/bin/bash
# Installs Nightdrive in one line: the website serves this file at nightdrive.sh/install (its build copies it from main).
#   curl -fsSL https://nightdrive.sh/install | bash
#   curl -fsSL https://nightdrive.sh/install | bash -s -- --dev --with deck   # the options go on to install.sh
# Clones the repo into ~/dotfiles (installing git first: a fresh Fedora lacks it) and runs ./install.sh there, which asks
# on the terminal as it does when started by hand. --dev clones the dev branch, the dev channel (`nightdrive channel`).
# A ~/dotfiles that is already a Nightdrive clone is used as it is (a second run after a failed install); anything else
# there stops it.
# Everything is in main(), called on the last line: bash reads a piped script as it runs it, so a download cut short
# runs nothing, and no command can read the rest of the script as its input.
set -euo pipefail

REPO_URL=https://github.com/nightdrive-sh/nightdrive.git
DIR=$HOME/dotfiles

main() {
  local branch=main args=() a
  for a in "$@"; do
    if [[ $a == --dev ]]; then branch=dev; else args+=("$a"); fi
  done
  (( EUID )) || { echo "Run this as your own user, not root: sudo asks for the password when it's needed." >&2; exit 1; }
  command -v dnf >/dev/null || { echo "Nightdrive installs on Fedora 44 (dnf not found)." >&2; exit 1; }

  # The pipe is curl's: install.sh asks its questions only when its input is a terminal, so give it the terminal.
  # Without one (a script, ssh without -t) it doesn't ask and installs the defaults, as install.sh does then.
  if { : </dev/tty; } 2>/dev/null; then exec </dev/tty; fi

  if [[ -e $DIR ]]; then
    # A clone made before the repo moved to the nightdrive-sh organisation still has the old address.
    local origin; origin=$(git -C "$DIR" remote get-url origin 2>/dev/null || true)
    if [[ $origin == *nightdrive-sh/nightdrive* || $origin == *jarilehtinen/nightdrive* ]]; then
      echo "==> Using the Nightdrive clone already in $DIR ($(git -C "$DIR" branch --show-current))"
    else
      echo "$DIR is already there and isn't a Nightdrive clone: move it aside and run this again." >&2
      exit 1
    fi
  else
    if ! command -v git >/dev/null; then
      echo "==> Installing git"
      sudo dnf install -y git
    fi
    echo "==> Cloning Nightdrive ($branch) into $DIR"
    git clone --branch "$branch" "$REPO_URL" "$DIR"
  fi
  cd "$DIR"
  exec ./install.sh "${args[@]}"
}

main "$@"
