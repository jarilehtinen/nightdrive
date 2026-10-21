# Known issues

Problems found on a real machine that Nightdrive doesn't fix for everyone yet, usually because they have been seen on one
machine or one network only. Each entry has a workaround. If you run into one too, please open an issue: a second report is
the signal to fix it in Nightdrive itself.

## Wi-Fi takes about a minute to connect after opening the lid (6 GHz)

**Seen:** MacBook (Apple Silicon, `brcmfmac`), Fedora Asahi Remix 44, a Wi-Fi 6E network that has 2.4, 5 and 6 GHz under one
name. Found 2026-10-13.

**Symptom:** after waking up, the Wi-Fi icon stays disconnected for about 50 seconds. It doesn't happen every time.

**Cause:** on waking up, the Mac sometimes joins the access point's 6 GHz radio. The association succeeds, but no traffic
gets through, so DHCP gets no address. NetworkManager waits for its full DHCP timeout (45 s), then joins the 5 GHz radio,
where the address arrives at once. In the journal:

```
wpa_supplicant: wld0: Channel list changed: 6 GHz was enabled
wpa_supplicant: wld0: Associated with <6 GHz BSSID>
NetworkManager: device (wld0): state change: ip-config -> failed (reason 'ip-config-unavailable')   # 45 s later
wpa_supplicant: wld0: Associated with <5 GHz BSSID>
```

Check with `journalctl -b | grep -E 'Lid opened|Associated with|ip-config-unavailable'`, and
`nmcli -f BSSID,FREQ device wifi list` shows which BSSID is on which band.

**Workaround:** keep that network on 5 GHz (this also leaves out 2.4 GHz):

```
nmcli connection modify "<network>" 802-11-wireless.band a
```

Undo: `nmcli connection modify "<network>" 802-11-wireless.band ""`.

**A fix for everyone could be:** leaving out 6 GHz for every connection, or a shorter DHCP timeout (`ipv4.dhcp-timeout`)
so that a dead radio is given up sooner.

## AirPlay audio to an Apple TV or HomePod plays nothing (OS 27)

**Seen:** Apple TV 4K (`AppleTV11,1`), tvOS 27.0 (24J361), `AirTunes/980.77.2`; PipeWire 1.6.9 on Fedora Asahi Remix 44.
Found 2026-10-16. Worked before the tvOS 27 update. Other AirPlay speakers (a Sony receiver) still work.

**Symptom:** the Apple TV shows up under Sound as an output and can be chosen, but nothing is heard, from any app.

**Cause:** Apple's OS 27 bug, not Nightdrive: Apple TV and HomePod refuse AirPlay 1 senders, which is what PipeWire's
AirPlay output (`module-raop-sink`) is. Even with *Allow Access: Anyone on the same network* the device answers the very
first RTSP request with `403 Forbidden`. Airfoil and OwnTone hit the same wall; Rogue Amoeba has reported it to Apple as
FB24452968 ([their note](https://rogueamoeba.com/support/knowledgebase/?showArticle=Airfoil-OS27-Issues),
[OwnTone #2047](https://github.com/owntone/owntone-server/issues/2047)). Check by hand:

```
exec 3<>/dev/tcp/<ip>/7000; printf 'OPTIONS * RTSP/1.0\r\nCSeq: 1\r\n\r\n' >&3; head -1 <&3   # RTSP/1.0 403 Forbidden
```

**Workaround:** use Screen Mirroring (Settings › Display), which speaks AirPlay 2 with pairing and carries the sound too.
The Sound menus show a refusing speaker in red with *no audio (Apple bug)* (`hypr/scripts/airplay-check`), and choosing it
in the launcher's Settings › Sound also gives a notification. The check is live, so the mark disappears by itself once Apple
fixes it, and then AirPlay audio is worth trying again.

**A fix for everyone could be:** an AirPlay 2 sender (pairing) for audio only, if Apple doesn't fix it.

## The Space preview in Files flashes a zoomed picture as it opens (Sushi 50)

**Seen:** MacBook (Apple Silicon) at scale 2, Fedora Asahi Remix 44, `sushi-50.0-1.fc44`. Found 2026-10-16.

**Symptom:** pressing Space on an image in Files opens the preview (Sushi), and for a moment the picture is shown too big and
cropped before it settles into the window.

**Cause:** Sushi's own window size, not Nightdrive. Sushi 50 is still GTK3, and on Wayland its `_getMaxSize()` divides the
monitor size by the scale factor although GTK already reports it in logical pixels, so on a scale-2 screen the preview
opens tiny (about 442×470 for a 1672×941 picture). Nightdrive's `float-quicklook` rule (hyprland.lua) makes it floating at
85 % of the screen instead, and the flash is Sushi drawing its first frame for its own small size before it redraws at the
rule's size. Without the rule's size there's no flash, but the preview stays tiny.

**Workaround:** none needed, the preview works. For a calm look at a picture, open it in the image viewer (double-click, Loupe),
which floats at the same 85 % without the flash.

**Expected fix:** Sushi 51 (GNOME 51) is ported to GTK4 and loads images with Glycin like Loupe, which replaces this window
code; it should reach Fedora with Fedora 45. Check then whether the flash is gone, and whether the `size` in `float-quicklook`
is still needed. If the bug survives, report or fix it upstream (gitlab.gnome.org/GNOME/sushi) rather than forking.

## 1Password's own keyboard shortcuts do nothing (Quick Access, Autofill)

**Seen:** 1Password 8.12.40 (native Wayland window), Hyprland 0.56.2, Fedora Asahi Remix 44. Found 2026-10-19.

**Symptom:** a key set in 1Password › Settings › General (Autofill as ⌘§, shown there as Meta+§; Quick Access, Lock)
is saved, but pressing it does nothing, in any app.

**Cause:** 1Password, not Nightdrive. On Linux the app catches its shortcuts the X11 way (`GrabKey` on the X server, in its
`index.node`), and on a Wayland desktop the X server only gets keys while an XWayland window has the focus, so practically
never. It doesn't use the Wayland way (the GlobalShortcuts portal): `hyprctl globalshortcuts` lists nothing.

**Workaround:** Hyper+P brings up the app. The rest that the app can do from the command line (`1password --quick-access`,
`--toggle`, `--lock`) can be given keys in `~/.config/hypr/local.lua`, e.g.
`hl.bind("SUPER + section", hl.dsp.exec_cmd("1password --quick-access"))`. Autofill has no command, so outside the browser
(where the 1Password extension fills) there is no workaround.

**A fix for everyone could be:** 1Password supporting the GlobalShortcuts portal (xdg-desktop-portal-hyprland has it). Running
1Password under XWayland and passing the key to it with Hyprland's `pass` might work, but it's untested and an XWayland
window can look blurry on a scaled screen.

## iPhone mirroring stops when a screen comes or goes (AirPlay Receiver)

**Seen:** MacBook (Apple Silicon), Fedora Asahi Remix 44, UxPlay 1.73.7, GStreamer 1.28.8. Found 2026-10-20.

**Symptom:** a mirrored iPhone, iPad or Mac screen disappears when the lid is closed or opened with an external display,
when the display is plugged in or out, or on `hyprctl reload`. The receiver itself is back within a second.

**Cause:** Hyprland announces the screens again, and GStreamer's `waylandsink` in UxPlay crashes (SIGSEGV, in
`gstwldisplay`'s `output_done`), even with nothing on screen. `coredumpctl list uxplay` shows one crash for each.

**Workaround:** start mirroring again from the phone. The receiver restarts UxPlay by itself and doesn't count a crash
right after a screen change (or config reload) towards its limit of five crashes in a minute, so it stays on.

**Cause, exactly:** `output_done` takes the display from the output with `g_object_steal_data`, which removes it, but a
compositor sends `wl_output.done` again after every change to a screen; the second time it's gone. Reported to GStreamer
as [#5329](https://gitlab.freedesktop.org/gstreamer/gstreamer/-/work_items/5329) (also
[#5144](https://gitlab.freedesktop.org/gstreamer/gstreamer/-/work_items/5144)).

**A fix for everyone could be:** GStreamer's fix, waiting as
[!11741](https://gitlab.freedesktop.org/gstreamer/gstreamer/-/merge_requests/11741) (a draft in October 2026). Once a
GStreamer release with it reaches Fedora, the receiver's crash exception and this entry can go.

## WezTerm from Flathub doesn't open a window

**Seen:** MacBook (Apple Silicon), Fedora Asahi Remix 44, Hyprland 0.56.2, Flathub's `org.wezfurlong.wezterm`
20240203-110809-5046fc22. Found 2026-10-20.

**Symptom:** WezTerm starts (its process and shell run, and starting it again says "Spawned your command via the
existing GUI instance"), but no window ever shows. XWayland (`--config enable_wayland=false`) and software rendering
(`--config "front_end='Software'"`) don't show one either.

**Cause:** Flathub's WezTerm is its last stable release, from February 2024, on the Flatpak runtime 23.08, which has
ended. Its Mesa has no Apple Silicon GPU driver (it draws with llvmpipe), and that release has Wayland problems with
newer compositors. WezTerm is developed further in nightly builds only. Install › Software › Terminals leaves it out
for this reason; a search still finds it.

**Workaround:** WezTerm's own nightly builds for Fedora (aarch64 and x86_64), not tried on Nightdrive yet:

```
sudo dnf copr enable wezfurlong/wezterm-nightly
sudo dnf install wezterm
```

Undo: `sudo dnf remove wezterm && sudo dnf copr remove wezfurlong/wezterm-nightly`.

**A fix for everyone could be:** offering the nightly builds in Terminals once they are tried here, or Flathub's
build again if it is updated.

## EasyEffects stops when an autoload file is broken (headphone EQ)

**Seen:** MacBook (Apple Silicon), Fedora Asahi Remix 44, EasyEffects 8.2.8. Found 2026-10-21, when Sony headphones were
switched off.

**Symptom:** the headphone EQ stops working, and `coredumpctl list easyeffects` shows a crash (SIGABRT).

**Cause:** EasyEffects, not Nightdrive. It watches its autoload folder (`~/.local/share/easyeffects/autoload/output`)
and reads every file that appears there. A file that is empty or not valid JSON throws an error that EasyEffects
doesn't catch, so it aborts (`ListModel::data` → `nlohmann::json parse_error` → `std::terminate` in the backtrace).
The file can be a half-written one: before 2026-10-21 Nightdrive's EQ (`topbar/scripts/eq`) saved the headphones'
autoload file in two steps, and switching the headphones off at the wrong moment left EasyEffects reading it in
between. The EQ now writes the file whole and moves it in place, so Nightdrive no longer causes this, but any other
broken file there still does. Reported to EasyEffects as
[#5415](https://github.com/wwmm/easyeffects/issues/5415).

**Workaround:** remove the broken file from the autoload folder (an empty one, or a name ending in `:.json`), then
choose an EQ in the headphones menu, which starts EasyEffects again, or start it with
`setsid -f easyeffects --service-mode -w`.

**A fix for everyone could be:** EasyEffects skipping a broken file (the fix suggested in #5415). Once a release with
it reaches Fedora, this entry can go.

## The Mac doesn't sleep after an external display was unplugged while it slept

**Seen:** MacBook (Apple Silicon), Fedora Asahi Remix 44, kernel 7.1.13-402.asahi, a 4K display on the HDMI port. Found
2026-10-21.

**Symptom:** the Mac went to sleep with an external display on HDMI, and the display was unplugged before it woke up. From
then on, it won't sleep: closing the lid or choosing Sleep turns the screen off for a moment and the Mac stays awake (it shows
the lock screen, and it is still online, e.g. in Tailscale). With the lid closed, the system tries again every 30 seconds and
fails each time.

**Cause:** the Asahi display driver, not Nightdrive. On waking up, the driver tries to bring back the picture on the HDMI port,
which no longer has a display, and that fails (`setmode failed`, `Modeset done, but pipe not enabled`). The port's display
pipe (CRTC) is left with its old mode while the connector is disconnected. Going to sleep checks every pipe, and
`dcp_crtc_atomic_check` (drivers/gpu/drm/apple/dcp.c) refuses a disconnected one that isn't being changed, so the display
driver fails to suspend and the whole sleep is cancelled. In the journal:

```
apple-dcp 289c00000.dcp: crtc_atomic_check: disconnected but no modeset
apple-drm soc:display-subsystem: PM: failed to suspend: error -22
systemd-sleep: Failed to put system to sleep. System resumed again: Invalid argument
```

Check with `journalctl -b | grep -E 'no modeset|failed to suspend'`; the first `setmode failed` after a wake-up shows when it
started.

**Workaround:** restart the Mac, which clears it. Plugging the display back in and unplugging it while the Mac is awake
should clear it too (not tried yet). To avoid it, unplug an external display while the Mac is awake, not while it sleeps.

**A fix for everyone could be:** the driver letting a pipe that is already off pass its check, or turning the pipe off
when the display is found gone on waking up. Not reported to Asahi yet; the closest reports are
[AsahiLinux/linux#303](https://github.com/AsahiLinux/linux/issues/303) (HDMI gives no picture after waking up) and
[#332](https://github.com/AsahiLinux/linux/issues/332) (the same `no modeset` line after waking up, M2 Mac mini). In
Nightdrive, a notification when sleep fails would at least tell why the Mac is still awake.
