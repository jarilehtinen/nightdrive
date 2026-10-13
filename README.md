# Nightdrive

**A synthwave-tinted Hyprland desktop for Apple Silicon Macs running Fedora Asahi Remix.**
Mac shortcuts, one launcher for everything, a top bar that behaves like the macOS menu bar, and a look you can change in a click.

![Nightdrive: Firefox, Deck playing FM-84 and the launcher on top](docs/screenshots/desktop.jpg)

**Hi, I'm Jari Lehtinen.** I've used a Mac for over 15 years. Every year or so I've tried a Linux distro or two, but none of them
stuck. Omarchy came closest, but I wanted something built entirely around my own preferences and the apps I actually use.
In my day job as a web developer, user interfaces and ease of use are at the core of what I do, and that's what I wanted from
my desktop too: ⌘ shortcuts, a launcher like Spotlight, a menu bar that just works, only faster and lighter.
So I installed Fedora Asahi on my MacBook Pro and built Nightdrive, evening by evening and with a lot
of help from Claude Code. If you're a Mac person curious about Linux on Apple Silicon, I hope it makes the jump easier.

> **Work in progress.** Nightdrive is my daily setup, published so others can use it or borrow from it. It has been tested on
> one machine so far (MacBook Pro 14″, M2 Max). Feedback, issues and ideas are very welcome.

## Why Nightdrive?

[Hyprland](https://hypr.land) is a great tiling compositor, but on its own it's a toolkit: no bar, launcher, theme or apps.
Nightdrive puts all of that together into one opinionated desktop, made for **Fedora Asahi**, **Apple Silicon** and
**habits from macOS**.

- **⌘ is the main key.** ⌘C / ⌘V / ⌘X work in every app, including the terminal. ⌘W closes, ⌘Q quits, ⌘Space opens the launcher.
- **Built for the MacBook.** The top bar sits in the notch area. The display uses a clean 2× scale. The top-row keys control
  volume, brightness, the keyboard backlight and dictation. Caps Lock is a second ⌘. Sleep is tuned for Asahi.
- **Everything is a keystroke away.** One launcher handles apps, passwords, clipboard history, emoji, screenshots, settings,
  installing packages and power. You rarely need a terminal for everyday things.
- **Simple and readable.** Plain config files, a few small scripts, and comments that explain *why*.

## Highlights

### A launcher for everything

**⌘Space** opens the launcher. It holds apps, 1Password items (copy a password, username or one-time code), clipboard history,
an emoji picker, screenshots, a colour picker, every keybinding, settings, `dnf` install / remove / update, and power actions.
Search from the top level finds all of these. While music plays, a player row sits above the list. Type a question and press
⌘⌥Enter to send it straight to Claude Code.

![The launcher](docs/screenshots/launcher.jpg)

### A top bar that behaves like a menu bar

Click an icon and a small menu opens under it: sound and output devices, Wi-Fi, Bluetooth, battery and brightness, Tailscale,
headphone EQ, system load and temperatures, the calendar, notifications, music, and your **Claude usage limits**. ⌘⇧Space lets
you walk through the menus with the arrow keys.

![Claude usage, system and calendar menus](docs/screenshots/menus.jpg)

### Make it yours in a click

Pick from seven theme colours: Violet, Blue, Teal, Green, Amber, Rose or Graphite. The colour changes the menus, launcher,
window borders, notifications, lock screen and top bar at once. Two synthwave wallpapers come with it, and you can add your own.
The top bar's opacity, icon colours and highlight colour are all settings in the launcher.

![Settings › Theme › Color with Teal selected](docs/screenshots/themes.jpg)

### Little things that add up

- **Shelf**: drag a file to the top edge of the screen to park it, then drag it into another app (like Dropover / Yoink).
- **Dictation**: hold F5 or Fn, speak, and let go. It runs fully offline with Voxtype and Parakeet ([setup](docs/dictation.md)).
- **Screensavers**: a synthwave sunset and a falling-characters rain, both drawn in the terminal.
- **Background apps**: ⌘W only hides chat apps and the music player, so they keep running. Their shortcut brings them straight back.
- **Web apps**: turn any site into an app window from the launcher (Install › Webapp).
- **Login screen** (optional): a password-only greeter that matches the theme.

![Screensavers: synthwave sunset and rain](docs/screenshots/screensavers.jpg)

## What's included

| | App | How it fits in |
|---|---|---|
| Window manager | [Hyprland](https://hypr.land) | Lua config, Mac-style keybindings, rounded screen corners |
| Bar, menus, launcher | [Waybar](https://github.com/Alexays/Waybar) + [Quickshell](https://quickshell.org) | one themed shell for the bar menus, launcher, OSD and shelf |
| Terminal | [kitty](https://sw.kovidgoyal.net/kitty/) | ⌘Enter; Mac copy and paste |
| Browser | Firefox | tabs below the address bar, themed UI |
| Mail | Thunderbird | themed, with a minimal toolbar ([details](docs/thunderbird.md)) |
| Music | [Deck](https://github.com/jarilehtinen/deck) (Spotify in the terminal) | bar icon, music menu, player row in the launcher, media keys |
| Passwords | 1Password + `op` CLI | Passwords level in the launcher, SSH agent |
| AI | [Claude Code](https://claude.com/claude-code) | ⌘⌥Enter, ask from the launcher, usage limits in the bar |
| Dictation | [Voxtype](https://github.com/peteonrails/voxtype) (Parakeet) | F5 / Fn push-to-talk, recording card on screen |
| Network | NetworkManager, BlueZ, [Tailscale](https://tailscale.com) | Wi-Fi, Bluetooth and Tailscale menus |
| Audio | PipeWire, [EasyEffects](https://github.com/wwmm/easyeffects) | output switching, EQ presets for headphones |
| Notifications | [mako](https://github.com/emersion/mako) | notification history and do not disturb in the bar |
| Files and images | Nautilus, Loupe | images open in Loupe, a simple viewer like Preview |
| Web apps | Chromium app windows | WhatsApp, Slack, Teams and YouTube by default; add your own |
| Lock and idle | hyprlock, hypridle | screensaver after 10 min, lock after 30 min |
| Optional | VS Code, Jottacloud | `install-vscode.sh`, `install-jotta.sh` |

## Requirements

- An **Apple Silicon Mac** (M1 or M2 series) with **[Fedora Asahi Remix](https://asahilinux.org/fedora/) 44**, the KDE edition.
- Tested on a MacBook Pro 14″ with an M2 Max. Other models should work, but you may need to adjust a few values (see
  [Make it yours](#make-it-yours)).

## Install

On a fresh Fedora Asahi Remix 44 with a network connection:

```sh
git clone https://github.com/jarilehtinen/nightdrive.git ~/dotfiles
cd ~/dotfiles
./install.sh              # packages, fonts, 1Password, the notch setting, config links, Deck, GTK tweaks, web apps
```

Then **reboot** and pick **Hyprland** as the session at the login screen. KDE stays installed as a fallback.

| Option | What it adds |
|---|---|
| `--greeter` | Replaces the login screen with the Nightdrive greeter (greetd + Quickshell). If it fails, press Ctrl+Alt+F3 and run `config/greeter/switch.sh off` |
| `--debloat` | Removes the default KDE apps |
| `--no-kde` | Removes Plasma completely (implies `--greeter`; experimental) |
| `--vm` | For trying Nightdrive in a Fedora 44 VM instead of an Asahi Mac (see below) |

A few things stay manual:
- `sudo tailscale up`
- In 1Password › Settings › Developer, turn on *SSH agent* and *Integrate with 1Password CLI*. The launcher's Passwords level
  needs the CLI integration.
- Sign in to Spotify in Deck.
- Optionally, set up dictation ([docs/dictation.md](docs/dictation.md)).

`./link.sh` on its own just (re)links the config files and is safe to run again. The repo can live anywhere; `~/dotfiles` is
only a convention.

<details>
<summary><b>Trying it in a virtual machine (experimental)</b></summary>

You can try most of the setup in an aarch64 **Fedora 44** VM on any Apple Silicon Mac, in Parallels Desktop or UTM with GPU
acceleration:

1. Create a Fedora 44 VM with 4 GB of RAM or more and 3D acceleration on.
2. Inside it: `git clone https://github.com/jarilehtinen/nightdrive.git ~/dotfiles && cd ~/dotfiles && ./install.sh --vm`
3. Log out and pick **Hyprland** at the login screen.

`--vm` skips the notch step and writes `config/hypr/local.lua` with scale 1.0, a software cursor and the rounded-corner shader off.
It must be Fedora 44, because the Hyprland COPR builds only for that release. Containers won't work, since Hyprland needs a GPU.
The battery and keyboard backlight controls stay empty in a VM.
</details>

## Keys

⌘ is the Super key, and Caps Lock works as a second ⌘.

| Keys | Action |
|---|---|
| ⌘ Space · ⌘ Enter | Launcher · terminal |
| ⌘ ⌥ Enter | Claude Code (with text typed in the launcher: sends it as the prompt) |
| ⌘ C / V / X | Copy / paste / cut, in every app |
| ⌘ W · ⌘ Q | Close (background apps are only hidden) · really quit |
| ⌘ F · ⌘ T · ⌘ J | Fullscreen · floating · split direction |
| ⌘ 1…0 · ⌘ ⇧ 1…0 | Go to workspace · move the window there |
| ⌘ ⇧ V · ⌘ ⇧ E | Clipboard history · emoji |
| ⌘ R · ⌘ ⇧ R | Screenshot of a region · of a window, to the clipboard |
| ⌘ ⇧ B / F / P / M / I | Browser / Files / 1Password / Music / Mail |
| ⌘ ⇧ Space | Walk through the top bar menus with the keyboard |
| ⌘ Esc | Notifications |
| F5 or Fn (hold) | Dictation |
| ⌘ ⇧ K | All shortcuts (also in the launcher under *Keybindings*) |

The full list is in [`config/hypr/SHORTCUTS.md`](config/hypr/SHORTCUTS.md).

## Make it yours

- **Machine settings.** The display scale and keyboard layout (Finnish Mac) are at the top of
  [`config/hypr/hyprland.lua`](config/hypr/hyprland.lua). These are the first things to change.
- **Per-machine overrides** go to `config/hypr/local.lua`, which git ignores.
- **Keybindings** are all in [`config/hypr/bindings.lua`](config/hypr/bindings.lua).
- **Web apps** are listed in [`config/webapps.txt`](config/webapps.txt). Apps that ⌘W should only hide are in
  [`config/hypr/background-apps`](config/hypr/background-apps).
- **Launcher apps**: only the apps in [`config/fuzzel/apps-allow.txt`](config/fuzzel/apps-allow.txt) are listed. Search finds
  the rest.
- **Private additions**: some things don't belong in a public repo, like work tools or a personal dashboard. You can keep them in
  your own private repo and link them into git-ignored *local* slots. Nightdrive loads them when they exist:

  | Slot | What you can add there |
  |---|---|
  | `config/hypr/local.d/*.lua` | autostart entries, window rules, keybindings |
  | `config/hypr/background-apps.local`, `SHORTCUTS.local.md` | more background apps, your own entries in the shortcut list |
  | `config/quickshell/local/` | `<Name>Menu.qml` bar menus, and `LauncherExtension.qml` for your own launcher levels |
  | `config/waybar/local.jsonc`, `local.css`, `status.local` | your own bar icons (the `group/local` module), their style and status |

## How it fits together

- **Waybar** draws the bar. Clicking an icon asks **Quickshell** to open `<Name>Menu.qml` under the cursor. Quickshell tells
  Waybar which menu is open, so the icon lights up.
- The menus use ordinary command-line tools such as `wpctl`, `nmcli`, `bluetoothctl`, `upower`, `tailscale`, `cliphist` and `dnf`.
  There are no daemons of their own.
- The theme script (`config/hypr/scripts/theme`) derives every shade from one colour. It writes a small file for Quickshell,
  mako, fuzzel and hyprlock, then reloads them.
- Deck writes its playing state to a small JSON file. The bar, the music menu and the launcher read that file.

## Good to know

- **Hyprland isn't in Fedora's aarch64 repositories.** The installer takes the `hypr*` packages from the COPR `arcaneon/arcos`
  and limits that repository to them.
- **Asahi specifics.** The notch area needs the `appledrm.show_notch=1` kernel argument, which the installer sets. The 16 KiB memory
  pages break a few Electron apps, but 1Password works.
- **The Claude usage menu** reads your plan's limits with Claude Code's own sign-in, so Claude Code must have been run once.
- **No credentials are stored in this repo.** Tokens stay with each app (Deck, Claude Code) or in 1Password.

## Credits

Inspired by [Omarchy](https://omarchy.org). Built on [Hyprland](https://hypr.land), [Quickshell](https://quickshell.org) and
[Waybar](https://github.com/Alexays/Waybar), on top of the [Asahi Linux](https://asahilinux.org) team's work. The colours start
from the [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) palette, and the icons are [Lucide](https://lucide.dev) (ISC).
The wallpapers were made with ChatGPT image generation for now. I'd much rather ship wallpapers by real artists, so if you make
synthwave art (or know someone who does) and would like it included, please get in touch. The Tailscale logo in the bar is Tailscale's trademark.

## License

[MIT](LICENSE). The bundled Lucide icon font is ISC-licensed.
