# Changelog

What each release of Nightdrive changed, newest first. `nightdrive update` shows the new ones when it's done, and
each is also the release's page on [GitHub](https://github.com/nightdrive-sh/nightdrive/releases).

## 0.4.0 – 2026-10-20

Better with an external display, more terminals to choose from, and a safer headphone jack.

- **An external display works like a second screen should.** Workspaces 1–9 are on the external display and the
  laptop's screen has one of its own (⌘0, a laptop icon in the bar). With the lid closed only the external display is
  used. Settings › Display › Laptop screen sets which side of the display the laptop is on, so the pointer crosses
  where the screens really meet. The bar on the screen without the focus dims its workspace, so you see where the
  keyboard goes.
- **Choose your terminal:** Install › Software › Terminals has Ghostty, Alacritty and foot next to kitty, each with
  Nightdrive's look and keys. Default apps sets which one ⌘Enter opens.
- **Headphone jack:** when something is plugged in, a notification asks whether it's headphones or speakers, and each
  keeps its own volume. Until you answer, the jack plays at most at 25 %, so headphones don't blast at the speakers'
  volume.
- **Low battery warning** at 10 % and 5 %.
- **⌘V pastes a picture in the terminal too**, e.g. a ⌘⇧S screenshot into Claude Code.
- **File pickers, Nautilus and other GTK windows** use the desktop's colours.
- **Crash reports to Claude** (Settings › Notifications, off by default): when a program crashes, a notification
  offers Ask Claude, which opens Claude Code to find out why, or Mute for that program.
- **Locking goes straight to the password prompt.** The logo and sounds are only at boot.
- **Fixes:**
  - Bluetooth: pairing a keyboard shows the passkey it asks for, a long device list scrolls, and device names show
    without stray colour codes.
  - Login screen: the prompt and startup sound are on one screen, and the prompt shows again under the lock.
  - Deck, 1Password and other background apps open centred on the screen you're on, and the drawer opens on the
    right screen.
  - Notifications: buttons with long text wrap, and photos are the right way up.
  - Software search no longer hangs on dnf's key prompt.
  - The screen's rounded top corners start under the bar at every scale.
- **Plugins:** Ferry's menu shows its name at the top, and a long list fades out under the device picker. Ferry shows a
  received image in its notification, and a phone sees a computer wake within seconds. AirPlay Receiver keeps working
  when screens change.

## 0.3.0 – 2026-10-19

- **Ferry sends to the device you pick:** one of your phones or another computer, from the pill in Ferry's menu. Only
  that device gets it. Another computer gets it straight away, and Send Clipboard puts it on that computer's clipboard.
- **Ferry's menu and phone page are new:** what arrived on one card, and Aa (a text), Send Clipboard and + (files) below
  it. Drag files over the menu to drop them on a device. Add Device is in the pill's list.
- **Undo for windows:** ⌘⇧U opens the window you closed with ⌘W again, where it was.
- File pickers open floating in the middle of the screen.

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

