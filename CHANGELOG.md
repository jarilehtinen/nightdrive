# Changelog

What each release of Nightdrive changed, newest first. `nightdrive update` shows the new ones when it's done, and
each is also the release's page on [GitHub](https://github.com/nightdrive-sh/nightdrive/releases).

## 0.2.0 – 2026-10-19

The first release tested on a real PC (Intel, NVIDIA RTX, a USB keyboard), with the fixes that came out of it.

- **The lock screen is now the login screen.** Locking (⌃⌘L, after the idle time, before sleep) shows the same screen
  as at boot, with the wallpaper behind it. Before, the lock showed a blurred picture of your windows, which could still
  be read.
- **Waking from sleep works on more machines.** On some PCs the password field took no keys after waking, or the lock
  didn't draw at all. The lock now starts again a moment after waking.
- **Claude Code comes with the install**, so ⌘⌥Enter and the launcher's questions work right away. Run `claude` once
  to log in.
- **Date format in the launcher:** Settings › Top bar › Date format, e.g. 19.10. or 10/19. A system installed in
  English showed 10/19 with no way to change it from the desktop.
- **Fixes:**
  - The display menu in the top bar now changes the scale (it didn't save it).
  - ⌘Enter and ⌘⌥Enter open a terminal again on a new install (the `~/Projects` folder they open in wasn't created).
  - Settings › Battery is gone on a computer without one (it stayed on "Loading…").
  - No more "config has errors" while `nightdrive update` runs, and no Hyprland "updated to …" window after it.
  - Deck uses less CPU while paused on Linux: it closes the sound output until you play again.
- **Dictation on a PC:** docs/dictation.md now covers the PC binaries and giving dictation a key of its own, as a PC
  keyboard has no mic key like the MacBook's F5.

## 0.1.0 – 2026-10-19

Nightdrive's first release. From now on the stable channel gets its changes as releases like this one, each with notes
on what's new.

- A keyboard-driven Hyprland desktop for Fedora, on an Apple Silicon Mac (Fedora Asahi Remix) or a PC: ⌘ shortcuts, one
  launcher for everything, and a top bar of small menus.
- Install it with one line: `curl -fsSL https://nightdrive.sh/install | bash`
- `nightdrive version` shows which release you have, and after an update that brings a new release, its notes are shown
  at the end.
- Optional parts as plugins, such as Ferry (files and the clipboard between your phone and computer), Deck (Spotify),
  LocalSend, AirPlay Receiver and Screen Mirroring.
- The project's new address is github.com/nightdrive-sh/nightdrive. The old links still work.

