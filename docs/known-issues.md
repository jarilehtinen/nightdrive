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

## The top bar turns black under the mouse and flickers

**Seen:** MacBook (Apple Silicon), Fedora Asahi Remix 44, Hyprland 0.56.2, aquamarine 0.14.0, Mesa 26.2.4. Found 2026-10-14.

**Symptom:** only when the bar is see-through (bar opacity below 100 %): moving the mouse over the top bar "paints" it black where the pointer goes, and the bar flickers between black
and its normal see-through background. Restarting the bar (`qs`) or `hyprctl reload` doesn't help, and neither does a
software cursor (`cursor:no_hardware_cursors`).

**Cause:** Hyprland's damage tracking. When only the damaged part of the bar is redrawn, the wallpaper under it isn't, so
the bar's semi-transparent black background is drawn over the previous frame again and again until it is fully black.
Turning damage tracking off makes it go away at once. It survives a reboot. Why it started is not known.

**Workaround:** redraw the whole screen every frame (costs a little battery), e.g. in `~/.config/hypr/local.lua`:

```lua
hl.config({ debug = { damage_tracking = 0 } })
```

Try it live first with `hyprctl eval 'hl.config({ debug = { damage_tracking = 0 } })'`. Undo: remove the line, or set it to
`2` (the default). Worth trying without it after the next Hyprland update.

**A fix for everyone could be:** finding which layer's damage is wrong (the bar, the wallpaper or the shelf overlay) and
reporting it upstream, or making the bar's background opaque (an opaque bar hides it, which is why it only shows with bar opacity).
