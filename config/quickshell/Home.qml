pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Home Assistant's devices for the launcher's Home level (HomeLevels.qml) and the top bar's Home menu (HomeMenu.qml):
// one copy of the states, so a toggle in one shows in the other. Data and actions: the Home Assistant plugin's
// bin/home-assistant (plugins/home-assistant, linked to ~/.local/bin).
// Nothing is polled on its own: the launcher level and the menu call refresh() while they're open.
QtObject {
    id: h
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/home-assistant"

    property bool configured: false
    property var states: []          // [{ id, name, domain, state, on, area, fav, detail, dimmable, bright }]
    property bool loaded: false
    property string error: ""
    property var pending: ({})       // id -> on: a toggle sent, shown until HA reports it (or a few seconds pass)
    property var pendingBright: ({}) // id -> 0..1: a brightness sent (or waiting to be sent), shown the same way
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

    function isOn(e) { return pendingBright[e.id] !== undefined ? pendingBright[e.id] > 0 : pending[e.id] !== undefined ? pending[e.id] : e.on }
    readonly property var oneShot: ["scene", "script", "automation", "button", "input_button"]   // Enter runs / presses
    function canToggle(e) { return oneShot.indexOf(e.domain) < 0 && e.domain !== "climate" }

    function toggle(e) {
        if (canToggle(e)) {
            const p = Object.assign({}, pending)
            p[e.id] = !isOn(e)
            const b = Object.assign({}, pendingBright)   // Enter after a slide: on/off wins over the brightness shown
            delete b[e.id]
            const q = Object.assign({}, brightQueue)
            delete q[e.id]
            brightQueue = q
            changing()
            pending = p
            pendingBright = b
            clearPending.restart()
        }
        Quickshell.execDetached(["bash", "-c", '"$1" toggle "$2" 2>&1 >/dev/null | { read -r m && notify-send -a "Home Assistant" -u critical "Couldn’t control the device" "$m"; }; true',
                                 "_", bin, e.id])
        soon.restart()
    }
    // ---- Brightness (dimmable lights): the launcher's slider row and ←/→, the Home menu's slider and scroll wheel ----
    // 0 = off. While a slider is dragged only the newest value goes out, at most every brightApply.interval ms.
    function bright(e) { return pendingBright[e.id] !== undefined ? pendingBright[e.id] : isOn(e) ? (e.bright || 0) : 0 }
    property var brightQueue: ({})   // id -> 0..1 not sent yet
    // A slider is being dragged: values go out, but nothing rebuilds the rows (a rebuild would drop the drag) — no new
    // states, no pendingBright — until it's let go; then the last value is shown as pending like any other
    property bool holding: false
    property string heldId: ""
    property real heldValue: 0
    function holdBright(on) {
        holding = on
        if (on) holdWatch.restart()
        if (on || heldId === "") return
        const e = states.find(x => x.id === heldId)
        heldId = ""
        if (e) setBright(e, heldValue)
    }
    function setBright(e, v) {
        v = Math.max(0, Math.min(1, Math.round(v * 100) / 100))
        if (holding) {
            heldId = e.id; heldValue = v
            const q = Object.assign({}, brightQueue); q[e.id] = v
            brightQueue = q
            if (!brightApply.running) brightApply.start()
            return
        }
        const p = Object.assign({}, pendingBright); p[e.id] = v
        const q = Object.assign({}, brightQueue); q[e.id] = v
        changing()
        pendingBright = p
        brightQueue = q
        clearPending.restart()
        if (!brightApply.running) brightApply.start()
    }
    // ←/→ and the wheel: steps on a grid of `step` % (12 % → 20 %, not 22 %); stepping down from the lowest step turns it off
    function stepBright(e, dir, step) {
        const s = step || 10
        const p = Math.round(bright(e) * 100)
        const n = dir > 0 ? (Math.floor(p / s) + 1) * s : (p % s === 0 ? p - s : Math.floor(p / s) * s)
        setBright(e, Math.max(0, Math.min(100, n)) / 100)
    }
    // In case the slider goes away while held (the launcher closed mid-drag) and never says it was let go
    property Timer holdWatch: Timer { interval: 15000; onTriggered: if (h.holding) h.holdBright(false) }
    property Timer brightApply: Timer {
        interval: 200
        onTriggered: {
            for (const id in h.brightQueue)
                Quickshell.execDetached(["bash", "-c", '"$1" brightness "$2" "$3" 2>&1 >/dev/null | { read -r m && notify-send -a "Home Assistant" -u critical "Couldn’t set the brightness" "$m"; }; true',
                                         "_", h.bin, id, String(Math.round(h.brightQueue[id] * 100))])
            h.brightQueue = ({})
            h.soon.restart()
        }
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
        if (pendingBright[e.id] !== undefined) return pendingBright[e.id] > 0 ? Math.round(pendingBright[e.id] * 100) + "%" : "off"
        if (pending[e.id] !== undefined) return pending[e.id] ? "on" : "off"
        return e.detail
    }
    readonly property var sectionNames: ({ light: "Lights", switch: "Switches", fan: "Fans", cover: "Covers", climate: "Climate",
                                           media_player: "Media", lock: "Locks", input_boolean: "Helpers", scene: "Scenes",
                                           script: "Scripts", automation: "Automations", button: "Buttons", input_button: "Buttons" })

    property Timer soon: Timer { interval: 700; onTriggered: h.refresh() }
    property Timer clearPending: Timer { interval: 5000; onTriggered: { h.changing(); h.pending = ({}); h.pendingBright = ({}) } }

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
            if (h.holding) return   // a slider is held: the next refresh after it's let go brings these
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
                // …and a brightness HA reports (255 steps: close enough), unless a newer one is still waiting to go out
                const b = Object.assign({}, h.pendingBright)
                for (const e of next)
                    if (b[e.id] !== undefined && h.brightQueue[e.id] === undefined && Math.abs((e.on ? e.bright : 0) - b[e.id]) < 0.02) delete b[e.id]
                // Rows are rebuilt only when something changed (each rebuild could move the selection)
                if (JSON.stringify(next) !== JSON.stringify(h.states) || Object.keys(p).length !== Object.keys(h.pending).length
                    || Object.keys(b).length !== Object.keys(h.pendingBright).length || h.error !== "") {
                    h.changing()
                    h.states = next
                    h.pending = p
                    h.pendingBright = b
                    h.error = ""
                }
            } catch (err) { h.error = "Unexpected answer from home-assistant states" }
            h.loaded = true
        }
    }
}
