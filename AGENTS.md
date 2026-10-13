# Agent notes

The config is **live**: `link.sh` symlinks `config/*` into `~/.config`, and Quickshell and Hyprland reload on save. Keep every
save valid, then check:
- Hyprland: `hyprctl configerrors` should be empty.
- Quickshell: `qs log | tail` should show no QML errors.
- Scripts: `bash -n` for shell, `ast.parse` for Python.
- Waybar doesn't reload by itself: `pkill -x waybar; setsid -f ~/.config/hypr/scripts/waybar-run`.

Test over IPC (`qs ipc show`, e.g. `qs ipc call launcher openLevel settings`) and take screenshots with `grim`.

**Pitfalls**
- Icons are invisible private-use glyphs in strings. Don't retype those lines, and compare the glyph counts with HEAD.
- `pkill -f foo` matches its own shell: use `'[f]oo'`.
- Hyprland's config is Lua: `hyprctl dispatch 'hl.dsp.…'`.

**Conventions**
- English comments that explain *why*.
- Colours come from `Theme.*` in QML and the bar-style colours in CSS (source: `THEMES` in `hypr/scripts/theme`).
- Machine-specific values are named constants at the top of each file.
- Nothing personal goes in the repo. Private additions use the git-ignored *local* slots (README › Make it yours).

**Recipes**
- *Bar icon and menu:* a case in `waybar/scripts/status`, a `custom/<name>` module in `config.jsonc` (on-click
  `scripts/menu <name>`), the same position in `shell.qml`'s `orderStart`/`orderEnd`, the selectors in `style.css`, and
  `quickshell/<Name>Menu.qml` (copy an existing menu).
- *Launcher level:* in `Launcher.qml`, add an item to `rootItems`/`statics`, entries in `titles` and `parents`, rows in
  `items()`, and actions in `activate()`.
- *Keybinding:* `hypr/bindings.lua`, and the same entry in `hypr/SHORTCUTS.md` (the launcher reads that file).
- *Command:* a subcommand in the case at the bottom of `bin/nightdrive` (link.sh links it to `~/.local/bin`).
