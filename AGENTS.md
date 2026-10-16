# Agent notes

The config is **live**: `link.sh` symlinks `config/*` into `~/.config`, and Quickshell and Hyprland reload on save. Keep every
save valid, then check:
- Hyprland: `hyprctl configerrors` should be empty.
- Quickshell: `qs log | tail` should show no QML errors.
- Scripts: `bash -n` for shell, `ast.parse` for Python.

Test over IPC (`qs ipc show`, e.g. `qs ipc call launcher openLevel settings`) and take screenshots with `grim`.
The user may be typing on this same desktop, and the launcher and menus take the keyboard: run `~/.local/bin/nightdrive
agent-warn "the launcher"` before opening one (once per burst of tests) and open it only after it returns (~5 s countdown
with sound). Use the full path: an agent's shell may not have `~/.local/bin` in its PATH, and if the command fails, don't
open anything.
Don't press Enter over IPC on rows that act on real things (Home Assistant devices, Power).
On a machine without Hyprland, or to leave the user's desktop alone, use the headless container: `nightdrive sandbox
check` (exit 1 with the findings) and `nightdrive sandbox shot NAME`, `ipc …` for the rest (docs/sandbox.md; no agent-warn there).

**Pitfalls**
- Menu icons are invisible private-use glyphs in strings. Don't retype those lines, and compare the glyph counts with HEAD.
  (The top bar uses icon names instead: `config/topbar/scripts/icon`.)
- `pkill -f foo` matches its own shell: use `'[f]oo'`.
- Hyprland's config is Lua: `hyprctl dispatch 'hl.dsp.…'`.
- Quickshell's reload on save keeps the old version of a component in its own file (e.g. `TouchScroll.qml`, listed in
  `qmldir`): restart it to test a change there (`qs kill; setsid -f qs`).

**Conventions**
- English comments that explain *why*.
- Colours come from `Theme.*` in QML, and the bar's from `TopBar.c()` (bar-style; source: `THEMES` in `hypr/scripts/theme`).
- Machine-specific values are named constants at the top of each file.
- Nothing personal goes in the repo. Private additions use the git-ignored *local* slots (README › Make it yours).

**Recipes**
- *Bar icon and menu:* an entry in `topbar/modules.jsonc` (its place in the bar), a case in `topbar/scripts/status`
  (`emit ICON TEXT CLASS`), and `quickshell/<Name>Menu.qml` (copy an existing menu). Size it with `nightdrive topbar adjust`.
- *Launcher level:* in `Launcher.qml`, add an item to `rootItems`/`statics`, entries in `titles` and `parents`, rows in
  `items()`, and actions in `activate()`.
- *Keybinding:* `hypr/bindings.lua`, and the same entry in `hypr/SHORTCUTS.md` (the launcher reads that file).
- *Command:* a subcommand in the case at the bottom of `bin/nightdrive` (link.sh links it to `~/.local/bin`).
