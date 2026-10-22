import QtQuick
import Quickshell

// The launcher's Settings › Apps › App shortcuts: which app Hyper (Caps Lock) + a letter or digit opens. One row per key
// in use, yours and the defaults (Nightdrive's, the plugins', your config's). "Add a shortcut" asks for the app, then a
// free key. Enter on a key in use asks for its new key (the free ones), and below them offers to change its app, put its
// default back or leave it free. Only these keys: the other shortcuts stay in the config files (hypr/bindings.lua, local.lua).
// Data and changes: hypr/scripts/app-keys. Launcher.qml asks it like DefaultAppsLevels (levels, titles, parents, items,
// activate, footer, entered).
Item {
    id: d
    property var launcher: null
    property var info: null                  // app-keys --json: { keys: [{ key, set, default, app }], free, apps }
    property bool adding: false              // Add a shortcut (app, then key) rather than changing a key in use
    property string key: ""                  // the key being changed (App shortcuts › Hyper B)
    property var app: ({ id: "", name: "" }) // Add a shortcut: the app chosen
    property string done: ""                 // the key just set: the cursor goes to it back in the list

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/app-keys"
    readonly property var levels: ["appkeys", "appkeyapp", "appkeykey"]
    readonly property var titles: ({ appkeys: "Apps › App shortcuts",
                                     appkeyapp: adding ? "App shortcuts › New" : "Hyper " + key + " › App",
                                     appkeykey: adding ? "App shortcuts › " + app.name : "App shortcuts › Hyper " + key })
    readonly property var parents: ({ appkeys: "appsettings", appkeyapp: adding ? "appkeys" : "appkeykey", appkeykey: adding ? "appkeyapp" : "appkeys" })
    readonly property var settingsItems: [{ kind: "nav", name: "App shortcuts", glyph: "keyboard", target: "appkeys" }]

    function footer(level, query) {
        const cur = launcher.results[launcher.selIndex] || {}
        if (cur.kind === "appkey") return "Enter: change"
        if (cur.kind === "appkeyadd") return "Enter: choose the app"
        if (cur.kind === "appkeyapp") return cur.current ? "" : adding ? "Enter: choose the key" : "Enter: use this"
        if (cur.kind === "appkeyto") return adding ? "Enter: use this key" : "Enter: move here"
        if (cur.kind === "appkeyval") return "Enter: use this"
        if (cur.kind === "appkeychange") return "Enter: choose"
        return ""
    }
    function opened() {}
    property bool fresh: false               // just entered: the cursor goes to the current one once the list is read
    function entered(level) { fresh = true; listProc.running = true }
    function shiftActivate(item) {}

    function open() { return ((info || {}).keys || []).find(k => k.key === key) || null }
    function note(text) { return { item: { kind: "note", name: text }, text: "" } }
    function row(item, text, extra) { return { item: item, text: text, extra: extra || "" } }

    function items(level, q) {
        if (info === null) return [{ kind: "hint", name: "Loading…" }]
        if (level === "appkeys") {
            const rows = info.keys.map(k => row({
                kind: "appkey", key: k.key, capKeys: "Hyper " + k.key,
                name: k.app ? k.app.name : k.set ? "No app" : k.default.name,
                sub: !k.set ? "Default · " + k.default.from : k.default ? "Default: " + k.default.name : undefined,
                dimmed: k.set && !k.app,
                iconFile: k.app ? k.app.icon : !k.set && k.default.icon ? k.default.icon : undefined,
                glyph: k.app || (!k.set && k.default.icon) ? undefined : k.set ? "circle-slash" : "app-window"
            }, k.app ? k.app.name : k.default ? k.default.name : "", "hyper " + k.key))
            return { all: [row({ kind: "appkeyadd", name: "Add a shortcut", glyph: "plus", chevron: true }, "Add a shortcut", "new")]
                              .concat(rows, [note("The other shortcuts are in ~/.config/hypr/bindings.lua")]) }
        }
        const k = open()
        if (level === "appkeyapp") {
            const cur = !adding && k && k.app ? k.app.id : ""
            // apps another key already opens are left out: their key is changed on their own row
            const taken = info.keys.map(x => x.app ? x.app.id : !x.set && x.default.app ? x.default.app : "").filter(id => id !== "" && id !== cur)
            return { all: info.apps.filter(a => taken.indexOf(a.id) < 0).map(a => row({ kind: "appkeyapp", id: a.id, name: a.name, current: a.id === cur,
                                                   iconFile: a.icon, trailGlyph: a.id === cur ? "check" : undefined }, a.name, a.id)) }
        }
        // appkeykey: the free keys, and for a key in use first what else can be done with it. A default whose app isn't
        // known (app-keys finds it by name) can't move.
        // a free key can be one whose default you left without an app: that default shows on its row
        const free = info.free.map(f => {
            const was = info.keys.find(x => x.key === f)
            return row({ kind: "appkeyto", key: f, name: "Hyper " + f, glyph: "keyboard",
                         sub: was && was.default ? "Default: " + was.default.name : undefined }, "Hyper " + f, f)
        })
        if (adding) return { all: free }
        const other = [row({ kind: "header", name: "Other" }, ""),
                       row({ kind: "appkeychange", name: "Change the app", glyph: "app-window", chevron: true }, "Change the app", "app")]
        if (k && k.set && k.default)
            other.push(row({ kind: "appkeyval", value: "default", name: "Default: " + k.default.name, sub: k.default.from, glyph: "rotate-ccw" }, "Default", "default"))
        if (k && (k.app || !k.set))   // in use: leave it free (a key with no default just goes)
            other.push(row({ kind: "appkeyval", value: k.default ? "none" : "default", name: "No app", glyph: "circle-slash" }, "No app", "none remove"))
        const movable = k && (k.app || (!k.set && k.default.app))
        return { all: (movable ? [row({ kind: "header", name: "New key" }, "")].concat(free) : []).concat(other) }
    }

    function activate(it) {
        if (it.kind === "appkey") { adding = false; key = it.key; launcher.go("appkeykey"); return true }
        if (it.kind === "appkeyadd") { adding = true; launcher.go("appkeyapp"); return true }
        if (it.kind === "appkeychange") { launcher.go("appkeyapp"); return true }
        if (it.kind === "appkeyapp") {
            if (it.current) { launcher.shakeNow(); return true }
            if (adding) { app = { id: it.id, name: it.name }; launcher.go("appkeykey"); return true }
            run(key, ["set", key, it.id])
            return true
        }
        if (it.kind === "appkeyto") {
            run(it.key, adding ? ["set", it.key, app.id] : ["move", key, it.key])
            return true
        }
        if (it.kind === "appkeyval") { run(key, ["set", key, it.value]); return true }
        return false
    }
    function run(selectKey, args) {
        done = selectKey
        setProc.command = ["bash", "-c", "exec 2>&1; \"$0\" \"$@\"", script].concat(args)   // its errors too
        setProc.running = true
    }

    Sh {
        id: listProc
        command: [d.script, "--json"]
        onResult: text => {
            let v
            try { v = JSON.parse(text) } catch (e) { return }
            const l = d.launcher
            if (!d.fresh) l.keepSelection()
            d.info = v
            if (d.fresh && l.level === "appkeyapp" && l.query === "") l.selectWhere(r => r.current === true)
            if (d.fresh && l.level === "appkeys" && l.query === "" && d.done !== "") { l.selectWhere(r => r.key === d.done); d.done = "" }
            d.fresh = false
        }
    }
    Sh {
        id: setProc   // then back to the list, which is read again (entered)
        onResult: text => {
            if (text.trim() !== "") Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "App shortcuts", "Couldn't change it", text.trim()])
            d.launcher.go("appkeys")
        }
    }
}
