# Nightdrive on a PC (experimental)

Nightdrive is built on a MacBook, but runs on an x86_64 PC with **Fedora 44 KDE**. The installer recognises the machine
(`nightdrive platform machine`: `asahi`, `pc` or `vm`) and prints it first, e.g.
`Machine: PC (x86_64, graphics: nvidia, keyboard: fi)`. Not yet tested on real PC hardware: a report helps (Discussions).

1. Install **Fedora 44 KDE Plasma Desktop** from [fedoraproject.org/kde](https://fedoraproject.org/kde/download) (the KDE
   edition: the package removals and `--no-kde` expect it; Fedora 44, because the Hyprland COPR builds for that release).
   The keyboard layout you pick in Fedora's installer is the one Nightdrive uses.
2. Install as in the [README](../README.md#install) and reboot.

## What differs from the MacBook

| | MacBook | PC |
|---|---|---|
| Display | scale 2.0 for the built-in display, the notch area for the top bar | scale picked by Hyprland from the display's size and resolution (`scale = "auto"`); change it in launcher › Settings › Display |
| Keyboard | the layout Fedora's installer set (`localectl`); a Finnish one is the Finnish Mac layout (`fi`, `mac`) | the layout Fedora's installer set, also on the login screen |
| ⌘ | the Command key | the Windows key: ⌘C / ⌘V / ⌘X copy, paste and cut in every app, and the rest of the shortcuts work as they are |
| Rounded screen corners | on (shader tuned for the MacBook's display) | off |
| Wi-Fi firmware | other chips' firmware removed | kept |
| Dictation mic | the MacBook's own mic, always | the default mic |
| Temperatures (system menu) | SSD, Wi-Fi, charger, speakers | CPU (Intel `coretemp`, AMD `k10temp`), AMD graphics, SSD |

The display and keyboard settings go to `config/hypr/local.lua` (not in the repo): delete it and run `./install.sh` again to
write it anew, or edit it. Without a battery or a keyboard backlight their parts are left out of the menus.

## NVIDIA

Hyprland needs NVIDIA's own driver. On a PC with an NVIDIA card the installer enables RPM Fusion, installs `akmod-nvidia`
and builds the module for the newest kernel before the reboot. `hyprland.lua` sets the driver's environment
(`LIBVA_DRIVER_NAME`, `__GLX_VENDOR_LIBRARY_NAME`, `NVD_BACKEND`) when the driver is loaded. `--no-nvidia` leaves the
driver alone, for one installed by hand.

**Secure Boot:** the module is signed with a key of this machine's own (`kmodgenca`). Before the reboot, run
`sudo mokutil --import /etc/pki/akmods/certs/public_key.der` and choose a one-time password; at the reboot the blue MOK
screen asks for it (Enroll MOK › Continue › Yes). Without that the driver doesn't load and the screen stays on Fedora's
basic driver. The installer reminds you at the end.

If the build hadn't finished by the reboot, akmods builds it at boot: `sudo journalctl -u akmods`, and
`modinfo nvidia` shows the version once it's there.
