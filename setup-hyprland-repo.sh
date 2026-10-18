#!/bin/bash
# The dnf repo of the Hyprland stack: Nightdrive's own COPR jarilehtinen/nightdrive (aarch64 and x86_64, specs in
# github.com/jarilehtinen/nightdrive-packages). Fedora's own repos have no Hyprland, and its Hyprland libraries are too
# old. includepkgs limits the COPR to the stack's packages, so it never replaces another Fedora package.
# It replaces arcaneon/arcos, the COPR Nightdrive used until 19.10.2026, whose aarch64 builds fell behind: its repo goes,
# and the next dnf upgrade moves the packages over (hyprland obsoletes hyprland-uwsm, hyprland-guiutils the Qt utilities).
# Run by install.sh, `nightdrive update` (only when something is to change) and the sandbox's Containerfile.
#   setup-hyprland-repo.sh           sets it up (sudo, unless run as root); safe to re-run
#   setup-hyprland-repo.sh --check   exit 1 when it would change something (no sudo)
set -euo pipefail
COPR=jarilehtinen/nightdrive
OLD=arcaneon/arcos
INCLUDE=hypr*,aquamarine,xdg-desktop-portal-hyprland,uwsm,lua5.5
repo_file() { ls /etc/yum.repos.d/*copr*"${1%/*}"*"${1#*/}"*.repo 2>/dev/null | head -1 || true; }

current() {
  local f; f=$(repo_file "$COPR")
  [[ -n $f ]] && grep -qxF "includepkgs=$INCLUDE" "$f" && grep -q '^enabled=1' "$f" && [[ -z $(repo_file "$OLD") ]]
}
if [[ ${1:-} == --check ]]; then current; exit; fi
current && exit 0

sudo=sudo; (( EUID == 0 )) && sudo=
if [[ -z $(repo_file "$COPR") ]]; then
  dnf copr --help >/dev/null 2>&1 || $sudo dnf -y install dnf5-plugins >/dev/null   # dnf copr (in Fedora's images already)
  $sudo dnf copr enable -y "$COPR"
fi
f=$(repo_file "$COPR")
$sudo sed -i -e '/^includepkgs=/d' -e "/^\[copr:/a includepkgs=$INCLUDE" -e 's/^enabled=0/enabled=1/' "$f"
echo "    $COPR: Hyprland's own packages only ($INCLUDE)"
if [[ -n $(repo_file "$OLD") ]]; then
  $sudo rm -f "$(repo_file "$OLD")"
  echo "    $OLD removed: the next dnf upgrade moves the Hyprland packages to $COPR"
fi
