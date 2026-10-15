pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Home Assistant's devices for the launcher's Home level (HomeLevels.qml) and the top bar's Home menu (HomeMenu.qml):
// one copy of the states, so a toggle in one shows in the other. Data and actions: hypr/scripts/home-assistant.
// Nothing is polled on its own: the launcher level and the menu call refresh() while they're open.
QtObject {
    id: h
    readonly property string bin: Quickshell.env("HOME") + "/.config/hypr/scripts/home-assistant"

    property bool configured: false
    property var states: []          // [{ id, name, domain, state, on, area, fav, detail }]
    property bool loaded: false
    property string error: ""
    property var pending: ({})       // id -> on: a toggle sent, shown until HA reports it (or a few seconds pass)
    readonly property var favorites: states.filter(e => e.fav)
    // Settings › Home: kinds left out of the launcher (rooms, search, counts); pinned devices show anyway.
    // ~/.local/state/nightdrive/home.json { hidden: [domains] }; no file = automations and buttons hidden (maintenance
    // buttons like Restart / Identify, and automations are logic, not things to press)
    readonly property var defaultHidden: ["automation", "button", "input_button"]
    property var hidden: defaultHidden
    readonly property var shown: states.filter(e => hidden.indexOf(e.domain) < 0)
    // The kinds in Settings › Home, in the launcher's section order; Buttons covers both button domains
    readonly property var kinds: [["Lights", ["light"]], ["Switches", ["switch"]], ["Fans", ["fan"]], ["Covers", ["cover"]],
                                  ["Climate", ["climate"]], ["Media", ["media_player"]], ["Locks", ["lock"]], ["Helpers", ["input_boolean"]],
                                  ["Scenes", ["scene"]], ["Scripts", ["script"]], ["Automations", ["automation"]], ["Buttons", ["button", "input_button"]]]
    readonly property string prefsFile: Quickshell.env("HOME") + "/.local/state/nightdrive/home.json"
    property FileView prefsView: FileView {
        path: h.prefsFile; watchChanges: true; onFileChanged: reload(); printErrors: false
        onLoaded: {
            let v = {}
            try { v = JSON.parse(text()) || {} } catch (e) {}
            const n = Array.isArray(v.hidden) ? v.hidden : h.defaultHidden
            if (JSON.stringify(n) !== JSON.stringify(h.hidden)) { h.changing(); h.hidden = n }
        }
    }
    function setHidden(domains, off) {
        const n = hidden.filter(d => domains.indexOf(d) < 0).concat(off ? domains : [])
        changing()
        hidden = n
        Quickshell.execDetached(["bash", "-c", 'mkdir -p "$(dirname "$2")" && printf "%s\\n" "$1" > "$2.tmp" && mv "$2.tmp" "$2"',
                                 "_", JSON.stringify({ hidden: n }), prefsFile])
    }
    signal changing()                // just before states / pending change: the launcher keeps its selected row

    // Launcher open / menu open: is it set up (cheap: reads the config file), then the states
    function check() { configuredProc.running = true }
    function refresh() { if (!statesProc.running) statesProc.running = true }

    function isOn(e) { return pending[e.id] !== undefined ? pending[e.id] : e.on }
    readonly property var oneShot: ["scene", "script", "automation", "button", "input_button"]   // Enter runs / presses
    function canToggle(e) { return oneShot.indexOf(e.domain) < 0 && e.domain !== "climate" }

    function toggle(e) {
        if (canToggle(e)) {
            const p = Object.assign({}, pending)
            p[e.id] = !isOn(e)
            changing()
            pending = p
            clearPending.restart()
        }
        Quickshell.execDetached(["bash", "-c", '"$1" toggle "$2" 2>&1 >/dev/null | { read -r m && notify-send -a "Home Assistant" -u critical "Couldn’t control the device" "$m"; }; true',
                                 "_", bin, e.id])
        soon.restart()
    }
    // Pin to / unpin from the top bar's Home menu
    function setFav(e, on) {
        changing()
        states = states.map(x => x.id === e.id ? Object.assign({}, x, { fav: on }) : x)
        Quickshell.execDetached([bin, "fav", e.id, on ? "on" : "off"])
    }

    // A kind's icon in Settings › Home (a device's own icon, on)
    function kindIcon(domain) { return domain === "input_boolean" ? "sliders-horizontal" : domain === "button" ? "circle-dot" : icon({ domain: domain, id: "", on: true }) }
    function icon(e) {
        const on = isOn(e)
        switch (e.domain) {
        case "light": return on ? "lightbulb" : "lightbulb-off"
        case "switch": case "input_boolean": return on ? "toggle-right" : "toggle-left"
        case "fan": return "fan"
        case "cover": return "blinds"
        case "climate": return "thermometer"
        case "media_player": return "speaker"
        case "lock": return on ? "lock-open" : "lock"
        case "scene": return "sparkles"
        case "script": return "scroll-text"
        case "automation": return on ? "zap" : "zap-off"
        default: return "circle-dot"
        }
    }
    // The row's right-hand text: what HA says (brightness, temperature…), or on/off right after a toggle
    function detail(e) {
        if (pending[e.id] !== undefined) return pending[e.id] ? "on" : "off"
        return e.detail
    }
    readonly property var sectionNames: ({ light: "Lights", switch: "Switches", fan: "Fans", cover: "Covers", climate: "Climate",
                                           media_player: "Media", lock: "Locks", input_boolean: "Helpers", scene: "Scenes",
                                           script: "Scripts", automation: "Automations", button: "Buttons", input_button: "Buttons" })

    property Timer soon: Timer { interval: 700; onTriggered: h.refresh() }
    property Timer clearPending: Timer { interval: 5000; onTriggered: { h.changing(); h.pending = ({}) } }

    property Sh configuredProc: Sh {
        command: [h.bin, "configured"]
        onExited: code => {
            h.configured = code === 0
            if (h.configured) h.refresh()
        }
    }
    property Sh statesProc: Sh {
        script: '"$HA" states'
        environment: ({ "HA": h.bin })
        onResult: text => {
            if (statesProc.exitCode !== 0) {
                h.error = text.trim().split("\n").pop() || "Home Assistant didn’t answer"
                h.loaded = true
                return
            }
            try {
                const next = JSON.parse(text)
                // A reported state that matches the pending one ends the wait
                const p = Object.assign({}, h.pending)
                for (const e of next) if (p[e.id] === e.on) delete p[e.id]
                // Rows are rebuilt only when something changed (each rebuild could move the selection)
                if (JSON.stringify(next) !== JSON.stringify(h.states) || Object.keys(p).length !== Object.keys(h.pending).length || h.error !== "") {
                    h.changing()
                    h.states = next
                    h.pending = p
                    h.error = ""
                }
            } catch (err) { h.error = "Unexpected answer from home-assistant states" }
            h.loaded = true
        }
    }
}
