# Agent notes

The config is **live**: `link.sh` symlinks `config/*` into `~/.config`, and Quickshell and Hyprland reload on save. Keep every
save valid, then check:
- Hyprland: `hyprctl configerrors` should be empty.
- Quickshell: `qs log | tail` should show no QML errors.
- Scripts: `bash -n` for shell, `ast.parse` for Python.

Test over IPC (`qs ipc show`, e.g. `qs ipc call launcher openLevel settings`) and take screenshots with `grim`. `launcher rows`
returns the open level's title, footer and rows as JSON: compare it before and after a change to the launcher.
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
  `qmldir`), and doesn't reload a plugin's menu at all: restart it to test a change there (`qs kill; setsid -f qs`).

**Branches**
- `main` is stable: stable-channel users get it with `nightdrive update`. Every change is made in `dev`, a fix to what
  users run too, and reaches `main` only in a release, once tested. Users pick their channel with `nightdrive channel`
  (stable or dev).
- Check the branch before committing (`git branch --show-current`): it is `dev`. No commits straight to `main` and no
  cherry-picks, so `main` is always an earlier point of `dev` and a release has nothing to conflict with.
- A release, and pushing, are the user's decisions: don't do either unasked. A release raises the versions first:
  `nightdrive plugins bump` (the patch of every plugin that changed; a bigger step by name, plugins/README.md ›
  Versions), its `plugin.conf` changes committed to `dev`, then `main` moves to `dev` (`git merge --ff-only dev`).

**Conventions**
- English comments that explain *why*.
- Colours come from `Theme.*` in QML, and the bar's from `TopBar.c()` (bar-style; source: `THEMES` in `hypr/scripts/theme`).
- Machine-specific values are named constants at the top of each file.
- Nothing personal goes in the repo. Private additions use the git-ignored *local* slots (README › Make it yours).

**Documentation**
- The README, `docs/*.md`, each plugin's `README.md` and the `SHORTCUTS.md` files are the documentation, and the website
  (nightdrive.sh: Documentation, Plugins) is built from them, not written separately. So a change users can see updates
  them in the same commit: a new feature, key, command or option gets its line there.
- A new `##` / `###` section in the README or a new file in `docs/` also needs a place in the website's contents
  (`data/docs.json` in the nightdrive-website repo). Its build (`tools/build.sh`) lists what has none and stops.

**Recipes**
- *Plugin* (an optional feature: a bar icon and menu, keys, a service): a folder `plugins/<id>/` as `plugins/README.md`
  explains (copy its Disk example, or `plugins/ferry`), then `nightdrive plugin check <id>`. After changing its
  `module.jsonc` or adding a menu, run `nightdrive plugins installed`; after changing its keys, `hyprctl reload`.
- *Bar icon and menu* in the core (on every desktop): an entry in `topbar/modules.jsonc` (its place in the bar), a case
  in `topbar/scripts/status` (`emit ICON TEXT CLASS`), and `quickshell/<Name>Menu.qml` (copy an existing menu). Size it
  with `nightdrive topbar adjust`. Every menu follows the rules in `plugins/README.md` › The menu: `MenuHeader` first, rows
  `MenuRow`, section titles `MenuSection`, hint and error lines `MenuNote`, colours `Theme.*`.
- *Launcher level:* a page or group of pages goes in its own `quickshell/<Name>Levels.qml` (copy `BehaviourLevels.qml`:
  `levels`, `titles`, `parents`, `items`, `activate`, `footer`, `entered`; optional keys: `extCtrl`, `extDelete`, `extMove` there),
  listed in `qmldir` and in `exts` in `Launcher.qml`; the row that opens it goes in `rootItems`/`statics` there.
- *Keybinding:* `hypr/bindings.lua`, and the same entry in `hypr/SHORTCUTS.md` (the launcher reads that file). An app opens
  with Hyper + a letter (`"MOD3 + X"`, `Hyper X` in SHORTCUTS.md); desktop features use ⌘⇧ / ⌘⌥; ⌘ + a letter is the apps'.
- *Command:* a subcommand in the case at the bottom of `bin/nightdrive` (link.sh links it to `~/.local/bin`).
