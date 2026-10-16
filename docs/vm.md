# Trying Nightdrive in a virtual machine

You can try the whole setup in an aarch64 **Fedora 44** VM on any Apple Silicon Mac. Tested in Parallels Desktop 27:

1. Download the **Fedora 44 KDE Plasma Desktop** live ISO for **aarch64** from [fedoraproject.org/kde](https://fedoraproject.org/kde/download)
   (the KDE edition, like Asahi Remix; Parallels' own Fedora download may be another release).
2. In Parallels: File › New › *Install from an image file*, tick *Customize settings before installation*, give it 8 GB of RAM
   (Deck's Rust build needs it) and under Graphics pick **Best for Retina display**. 3D acceleration (VirGL) is on by default
   for Linux on ARM; Parallels Tools aren't needed.
3. Install Fedora to the disk with an administrator user, reboot and check `sudo dmesg | grep virgl` shows `+virgl`.
4. Optional: to work in the Mac's Terminal (copy and paste) instead of the VM window, run
   `sudo dnf install -y openssh-server && sudo systemctl enable --now sshd` and `ssh` to the address `ip -4 -br a` prints.
5. Install as in the [README](../README.md#install) and reboot. The installer detects the VM (`systemd-detect-virt`);
   `./install.sh --vm` forces it.
6. To use ⌘ as Super inside the VM, set Parallels' VM settings › Hardware › Mouse & Keyboard › *Send macOS system shortcuts*
   to *Always*.
7. After restoring a snapshot, run `sudo systemctl restart chronyd` and check `date` a few seconds later: the VM's clock
   goes back with the snapshot (without Parallels Tools nothing syncs it with the Mac), chrony only slews a big gap
   slowly, and dnf rejects new packages whose signatures look made in the future.

On a VM the installer skips the notch step and writes `config/hypr/local.lua` with scale 2.0 (for *Best for Retina display*; pick 1.0 in the
launcher's Settings › Display for *Scaled*), a software cursor, the rounded-corner shader off and, unless it's Finnish, the keyboard layout Fedora's installer set. It must be Fedora 44,
because the Hyprland COPR builds only for that release. Containers won't work, since Hyprland needs a GPU. Parallels passes
the Mac's battery to the VM; without a display or keyboard backlight their sliders are left out.
