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
# dnf5 vendor change policy: the stack's packages may move to this COPR from arcos (and from Fedora's own, older
# Hyprland libraries). Fedora Asahi Remix turns vendor changes off (allow_vendor_change=False, "sticky vendors"), so
# without it dnf skips them ("vendor change restriction") and hyprland-guiutils can't replace arcos's Qt utilities.
# includepkgs keeps the COPR to the stack, so nothing else can move.
VENDORS=/etc/dnf/vendors.d/nightdrive-hyprland.conf
vendors() {
  printf '%s\n' "# Written by Nightdrive's setup-hyprland-repo.sh: the Hyprland stack may move to its COPR" "version = '1.1'" "" \
    "[[incoming_vendors]]" "vendor = 'Fedora Copr - user ${COPR%/*}'" "" \
    "[[outgoing_vendors]]" "vendor = 'Fedora Copr - user ${OLD%/*}'" "" \
    "[[outgoing_vendors]]" "vendor = 'Fedora Project'"
}

current() {
  local f; f=$(repo_file "$COPR")
  [[ -n $f ]] && grep -qxF "includepkgs=$INCLUDE" "$f" && grep -q '^enabled=1' "$f" && [[ -z $(repo_file "$OLD") ]] &&
    [[ $(cat "$VENDORS" 2>/dev/null) == "$(vendors)" ]]
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
if [[ $(cat "$VENDORS" 2>/dev/null) != "$(vendors)" ]]; then
  $sudo mkdir -p "${VENDORS%/*}"; vendors | $sudo tee "$VENDORS" >/dev/null
  echo "    $VENDORS: dnf may move the packages to it from arcaneon/arcos (and from Fedora's own)"
fi
if [[ -n $(repo_file "$OLD") ]]; then
  $sudo rm -f "$(repo_file "$OLD")"
  echo "    $OLD removed: the next dnf upgrade moves the Hyprland packages to $COPR"
fi
