#!/bin/bash
# AirDrop with iPhones, iPads and Macs: the radio side. AirDrop runs over AWDL, Apple's own Wi-Fi link, which the
# Broadcom Wi-Fi in Apple Silicon Macs (BCM4378/4387/4388: M1 and M2) already implements in its firmware. omdrop-awdl
# (https://github.com/netmojo-systems/omdrop-awdl, GPL-2.0) patches Linux's brcmfmac driver to expose it as an awdl0
# interface and brings the root helpers that make the computer visible and send files. This installs:
#   - the patched brcmfmac as a DKMS module, rebuilt on every kernel update (if a build fails, the kernel's own driver
#     loads: AirDrop stops, the Wi-Fi keeps working)
#   - the helpers in /usr/lib/omdrop, a polkit rule that lets the desktop session make the computer visible without a
#     password, and awdl0.service, which creates awdl0 at boot without advertising anything
# Nightdrive's own side (receiving, notifications, Files › Send with AirDrop) is hypr/scripts/airdrop.
#
# Reviewed at the pinned commit on 2026-10-16: the vendored kernel sources are byte-identical to Asahi's
# asahi-7.1.13-3, the patches and helpers do nothing beyond AWDL. Two things are changed here on the way in:
#   - omdrop-discoverable (root through polkit, no password) and awdl-up run inline Python, which imports from the
#     working directory first, and `pkexec --keep-cwd` keeps the caller's: any program running as the user could plant
#     a struct.py and get root. Both scripts `cd /` once they have found their own directory.
#   - packaging/brcmfmac-awdl.conf (debug=0x1000) isn't installed: with the module's debug build it hex-dumps every
#     firmware command to the kernel log, Wi-Fi keys included, and the journal keeps them. No helper needs it.
# And one setting of the system's: Fedora gives each Wi-Fi network a MAC address of its own (stable-ssid,
# /usr/lib/NetworkManager/conf.d/22-wifi-mac-addr.conf), and awdl-up refuses to derive awdl0's address from anything but
# the hardware's, so awdl0 never came up. A file of the same name in /etc hides it: the Wi-Fi keeps the hardware MAC on
# every network, so networks can recognise the computer from one to another, as with AirDrop on a Mac.
#
# Source: ~/.local/src/omdrop-awdl at the reviewed commit (another one: OMDROP_AWDL_REF=<commit> ./install-airdrop.sh,
# unreviewed). Remove: ./install-airdrop.sh --remove. Run as a regular user; sudo asks for the password.
set -euo pipefail
repo=$(cd "$(dirname "$0")" && pwd)
src=$HOME/.local/src/omdrop-awdl
ref=${OMDROP_AWDL_REF:-fe05b2c575db063c388abb0c31c840c03b1b6412}   # v0.9.3, patches for asahi-7.1.13-3
name=brcmfmac-awdl
kver=$(uname -r)

remove_dkms() {   # every version installed earlier, so DKMS has one source of the module
  local v
  for v in $(sudo dkms status -m "$name" 2>/dev/null | sed -n "s|^$name/\([^,:]*\).*|\1|p" | sort -u); do
    sudo dkms remove -m "$name" -v "$v" --all || true
    sudo rm -rf "/usr/src/$name-$v"
  done
}

if [[ ${1:-} == --remove ]]; then
  [[ -x $repo/config/hypr/scripts/airdrop ]] && "$repo/config/hypr/scripts/airdrop" disable || true
  sudo systemctl disable --now awdl0.service 2>/dev/null || true
  remove_dkms
  sudo rm -rf /usr/lib/omdrop /usr/share/polkit-1/actions/org.omarchy.omdrop.policy /etc/systemd/system/awdl0.service \
    /etc/NetworkManager/conf.d/99-awdl-unmanaged.conf /etc/NetworkManager/conf.d/22-wifi-mac-addr.conf \
    /etc/depmod.d/brcmfmac-awdl.conf
  sudo systemctl daemon-reload
  sudo depmod -a "$kver"
  echo "AirDrop removed. The kernel's own Wi-Fi driver is back after a restart."
  exit
fi

if [[ $(uname -m) != aarch64 ]] || ! grep -qsx 0x14e4 /sys/class/net/*/device/vendor; then
  echo "AirDrop needs an Apple Silicon Mac with its Broadcom Wi-Fi (M1 or M2)." >&2
  exit 1
fi

# The headers must be the running kernel's exact version: DKMS builds against /lib/modules/$kver/build, and without
# them it builds nothing and the stock driver stays. 7.1.13-402.asahi.fc44.aarch64+16k → kernel-16k-devel-7.1.13-….
flavor=${kver##*+}; [[ $flavor == "$kver" ]] && flavor=
devel="kernel${flavor:+-$flavor}-devel-${kver%+*}"
# Pillow draws the sender's icon, libarchive packs the transfers, zeroconf/ifaddr browse mDNS, keyutils for keyctl;
# git applies the patches (a lean system has no patch(1)).
sudo dnf install -y dkms "$devel" git python3-libarchive-c python3-pillow python3-zeroconf python3-ifaddr keyutils openssl

[[ -d $src/.git ]] || git clone -q https://github.com/netmojo-systems/omdrop-awdl "$src"
git -C "$src" fetch -q --tags origin 2>/dev/null || echo "Warning: couldn't fetch omdrop-awdl, using $src as it is" >&2
git -C "$src" checkout -q "$ref"
ver=$(git -C "$src" describe --tags --always HEAD | sed 's/^v//')

# Everything is staged first and copied as root only at the end. The DKMS tree: the vendored Asahi brcmfmac with the
# patches applied to a copy (the checkout stays clean), laid out like omdrop-awdl's PKGBUILD: sources beside dkms.conf.
# git apply runs outside any repository, so it resolves the paths against the copy.
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -a "$src/kernel" "$stage/kernel"
(cd "$stage/kernel" && git apply "$src"/patches/*.patch)
b="$stage/kernel/drivers/net/wireless/broadcom/brcm80211"
mkdir "$stage/$name-$ver"
cp -r "$b/brcmfmac" "$b/brcmutil" "$b/include" "$stage/$name-$ver/"
printf 'obj-m += brcmfmac/\nobj-m += brcmutil/\n' > "$stage/$name-$ver/Makefile"
sed "s/@VERSION@/$ver/" "$src/dkms.conf.in" > "$stage/$name-$ver/dkms.conf"

mkdir "$stage/lib"
cp "$src"/userspace/* "$stage/lib/"
for s in omdrop-discoverable awdl-up; do
  sed -i '0,/^LIB=.*/s//&\ncd \/ || exit 2   # Nightdrive: not the caller'"'"'s directory, inline Python imports from it as root/' \
    "$stage/lib/$s"
  grep -q '^cd / || exit 2' "$stage/lib/$s" || { echo "Couldn't harden $s: its LIB= line has moved" >&2; exit 1; }
done

remove_dkms
sudo cp -r "$stage/$name-$ver" /usr/src/
# Fedora's DKMS may put the module in extra/ rather than updates/: both come before the kernel's own driver.
echo "search updates extra built-in" | sudo tee /etc/depmod.d/brcmfmac-awdl.conf >/dev/null
sudo dkms install -m "$name" -v "$ver" -k "$kver"

# The root side, at the paths the polkit rule names (root-owned, so the rule can't be pointed at a user's script).
sudo rm -rf /usr/lib/omdrop
sudo install -d /usr/lib/omdrop
sudo install -m755 "$stage/lib/omdrop-discoverable" "$stage/lib/awdl-up" "$stage/lib/send-to-peer" \
  "$stage/lib/awdl-resolve" /usr/lib/omdrop/
for h in awdl-airdrop-adv awdl-election awdl-mdns-respond awdl-peer-watch awdl-peers awdl-stats ble-airdrop-adv \
         brcm_iovar mkpsf awdl-af-parse airdrop-send; do
  sudo install -m755 "$stage/lib/$h.py" /usr/lib/omdrop/
done
sudo install -m644 "$stage/lib/awdl_identity.py" "$stage/lib/awdl_debug.py" /usr/lib/omdrop/
sudo install -Dm644 "$src/packaging/org.omarchy.omdrop.policy" /usr/share/polkit-1/actions/org.omarchy.omdrop.policy
sudo install -Dm644 "$src/packaging/awdl0.service" /etc/systemd/system/awdl0.service
sudo install -Dm644 "$src/packaging/99-awdl-unmanaged.conf" /etc/NetworkManager/conf.d/99-awdl-unmanaged.conf
printf '# Installed by Nightdrive install-airdrop.sh: hides Fedora'"'"'s stable-ssid default of the same name, as AirDrop (awdl0)\n# needs the hardware MAC. Remove: install-airdrop.sh --remove\n[connection.22-wifi-mac-addr]\nmatch-device=type:wifi\nwifi.cloned-mac-address=permanent\n' \
  | sudo install -Dm644 /dev/stdin /etc/NetworkManager/conf.d/22-wifi-mac-addr.conf
sudo nmcli general reload conf 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl enable awdl0.service

echo
echo "Driver: $(modinfo -k "$kver" -n brcmfmac)"
if modinfo -k "$kver" -F parm brcmfmac | grep -q '^awdl_create_flags:'; then
  echo "The AirDrop Wi-Fi driver is installed and loads at the next restart. The Wi-Fi uses the hardware MAC from its next"
  echo "connection."
else
  echo "Warning: the kernel's own brcmfmac would still load, so AirDrop won't work. See: sudo dkms status" >&2
  exit 1
fi
