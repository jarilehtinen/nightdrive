import QtQuick
import Quickshell

// The launcher's Settings › Theme: Color (the desktop's accent; the launcher recolors at once) and Background (the
// wallpapers, yours and the bundled ones; ⌘⌫ moves one of yours to the trash). Background's rows are drawn as a grid
// by Launcher.qml (grid, once wallLoaded), which also marks wallCurrent there.
// Launcher.qml asks it like DefaultAppsLevels (levels, titles, parents, items, activate, footer, entered), and also
// deleteSelected (⌘⌫, Delete).
Item {
    id: t
    property var launcher: null

    property var themeList: []                // Color: [{ value, name, swatch, current }] (hypr/scripts/theme list)
    property var wallList: []                 // Background: [{ path, thumb, name, group, own }] (hypr/scripts/wallpaper list)
    property bool wallLoaded: false
    property string wallCurrent: ""           // the current wallpaper

    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts"
    readonly property var levels: ["theme", "themecolor", "background"]
    readonly property var titles: ({ theme: "Settings › Theme", themecolor: "Settings › Theme › Color", background: "Settings › Theme › Background" })
    readonly property var parents: ({ theme: "settings", themecolor: "theme", background: "theme" })

    function footer(level, query) { return "" }
    function opened() {}
    function entered(level) {
        if (level === "background") wallProc.running = true
        if (level === "theme" || level === "themecolor") themeProc.running = true
    }
    function shiftActivate(it) {}

    // Theme: Color with its current value, and Background (the root search finds them too)
    function themeItems() {
        const cur = themeList.find(c => c.current)
        return [
            { kind: "nav", name: "Color", glyph: "palette", target: "themecolor", summary: cur ? cur.name.toLowerCase() : undefined },
            { kind: "nav", name: "Background", glyph: "wallpaper", target: "background" }
        ]
    }

    function items(level, q) {
        if (level === "theme") return { all: themeItems().map(i => ({ item: i, text: i.name, extra: launcher.settingsAliases[i.name] || "" })) }
        if (level === "themecolor") {
            if (themeList.length === 0) return [{ kind: "hint", name: "Loading…" }]
            return { all: themeList.map(c => ({ item: { kind: "themecolor", value: c.value, name: c.name, swatch: c.swatch,
                                                        summary: c.current ? "current" : (c.value === "violet" ? "default" : undefined) }, text: c.name })) }
        }
        if (level === "background") {
            if (!wallLoaded) return [{ kind: "hint", name: "Loading backgrounds… (first time creates previews)" }]
            // "Add new…" first: an image of your own from a file picker
            return { all: [{ item: { kind: "walladd", name: "Add new…" }, text: "Add new", extra: "import file" }]
                .concat(wallList.map(w => ({ item: Object.assign({ kind: "wall" }, w), text: w.name, extra: w.group }))) }
        }
        return []
    }

    function activate(it) {
        const l = launcher
        if (it.kind === "themecolor") {   // stays open: colors can be tried one after another, and recolor the launcher at once
            l.keepSelection()
            themeList = themeList.map(c => Object.assign({}, c, { current: c.value === it.value }))
            Quickshell.execDetached([scripts + "/theme", "color", String(it.value)])
            return true
        }
        if (it.kind === "walladd") {      // the launcher closes while the picker is open; the script reopens Background
            l.open = false
            Quickshell.execDetached([scripts + "/wallpaper", "add"])
            return true
        }
        if (it.kind === "wall") {         // the launcher stays open: wallpapers can be tried one after another, Esc closes
            wallCurrent = it.path
            Quickshell.execDetached([scripts + "/wallpaper", "set", it.path])
            return true
        }
        return false
    }
    // ⌘⌫ in Background (bindings.lua → IPC deleteSelected) or Delete: a second press moves your own image to the trash.
    // Only your own images (~/Pictures/Wallpapers, `own` from hypr/scripts/wallpaper list); bundled ones can't be deleted.
    function deleteSelected() {
        const l = launcher
        if (l.level !== "background" || !wallLoaded) return false
        const it = l.results[l.selIndex]
        if (!it || it.kind !== "wall" || !it.own) { l.shakeNow(); return true }
        if (!arm("del:" + it.path)) return true
        if (wallCurrent === it.path) wallCurrent = ""
        wallList = wallList.filter(w => w.path !== it.path)
        if (l.selIndex >= l.results.length) l.select(l.results.length - 1)
        Quickshell.execDetached([scripts + "/wallpaper", "remove", it.path])
        wallReload.restart()
        return true
    }
    function arm(key) {
        if (launcher.armed !== key) { launcher.armed = key; disarmTimer.restart(); return false }
        launcher.armed = ""
        return true
    }
    Timer { id: disarmTimer; interval: 4000; onTriggered: if (t.launcher) t.launcher.armed = "" }
    Timer { id: wallReload; interval: 600; onTriggered: wallProc.running = true }   // current wallpaper (the default, if the deleted one was in use)

    // Background: wallpapers and their previews (the script creates missing previews the first time)
    Sh {
        id: wallProc
        script: 's="$HOME/.config/hypr/scripts/wallpaper"; "$s" current; "$s" list'
        onResult: text => {
            const lines = text.split("\n").filter(l => l !== "")
            t.wallCurrent = lines.length ? lines[0] : ""
            t.wallList = lines.slice(1).map(l => l.split("\t")).filter(f => f.length >= 4)
                .map(f => ({ path: f[0], thumb: f[1], name: f[2], group: f[3], own: f[4] === "1" }))
            const first = !t.wallLoaded
            t.wallLoaded = true
            // On open, select the current wallpaper
            if (first || t.launcher.query === "") t.launcher.selectWhere(r => r.path === t.wallCurrent)
        }
    }
    // Color: themes and the current one; select the current one
    Sh {
        id: themeProc
        command: [t.scripts + "/theme", "list"]
        onResult: text => {
            t.themeList = text.split("\n").map(l => l.split("\t")).filter(f => f.length >= 3)
                .map(f => ({ value: f[0], name: f[1], swatch: f[2], current: f[3] === "current" }))
            const l = t.launcher
            if (l.level === "themecolor" && l.query === "") l.selectWhere(r => r.value === (t.themeList.find(c => c.current) || {}).value)
        }
    }
}
