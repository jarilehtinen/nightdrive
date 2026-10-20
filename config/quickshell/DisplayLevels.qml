import QtQuick
import Quickshell

// The launcher's Settings › Display (brightness, night light, Screen Mirroring's rows from SystemLevels.qml, where the
// laptop's screen is next to an external one, and each output's scales) and Battery (charge and state, then the details, as in the top bar's battery menu).
// The brightness row is a slider that Launcher.qml draws (bright, setBright) and ←/→ steps (stepBright), also in the root
// search; Launcher.qml's displayItems() puts it there.
// Launcher.qml asks it like DefaultAppsLevels (levels, titles, parents, items, activate, footer, entered).
Item {
    id: p
    property var launcher: null

    property var displays: null               // [{ name, desc, scale, opts: [{ value, size }] }] (hypr/scripts/display list)
    property string side: ""                  // the laptop's screen: left | right | above | below | auto (display side)
    property real bright: -1                  // Brightness: 0..1 (brightnessctl), -1 = no backlight (a VM) or not read yet
    property real pendingBright: -1           // the slider's value waiting to be applied (throttled, like in BatteryMenu)
    property string night: ""                 // Night light: on | off (hypr/scripts/nightlight status)
    property var batt: null                   // Battery: { percent, state, timeText } (upower)
    property var battDetail: null             // and its details (topbar/scripts/sysinfo battery), null on a desktop
    property bool hasBattery: false           // the machine has its own battery: Settings lists Battery only then
    readonly property int brightStep: 5       // ←/→ on the brightness row, the same step as the brightness keys (hypr/scripts/brightness)

    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts"
    readonly property var levels: ["display", "battery"]
    readonly property var titles: ({ display: "Settings › Display", battery: "Settings › Battery" })
    readonly property var parents: ({ display: "settings", battery: "settings" })

    // The brightness and night light rows' footers are Launcher.qml's: the root search has them too
    function footer(level, query) { return "" }
    // On every open: the root search has the brightness and night light rows too
    function opened() { brightProc.running = true; nightProc.running = true }
    function entered(level) {
        if (level === "display") { displayProc.running = true; sideProc.running = true; brightProc.running = true; nightProc.running = true }
        if (level === "battery") { battProc.running = true; battDetailProc.running = true }
    }
    function shiftActivate(it) {}

    function items(level, q) {
        const l = launcher
        if (level === "display") {
            // Two sections: Brightness (a slider row, when there is a backlight) and Scale
            if (displays === null) return l.hint("Loading…")
            const out = bright < 0 ? [] : [{ kind: "header", name: "Brightness" },
                                           { kind: "brightness", name: "Screen", glyph: "sun", summary: Math.round(bright * 100) + "%" }]
            if (night !== "") {
                if (bright < 0) out.push({ kind: "header", name: "Brightness" })
                out.push({ kind: "nightlight", name: "Night light", glyph: "moon", switchOn: night === "on" })
            }
            // Scales the panel divides evenly, shown as the resulting desktop size ("looks like" in macOS); current one marked
            out.push(...l.mirrorRows())   // Screen Mirroring (AirPlay; SystemLevels.qml), empty without doubletake
            // Where the laptop's own screen is, so the pointer crosses where the screens meet: only with both on.
            // eDP is the connector of a laptop's panel (BUILTIN_DISPLAY in hyprland.lua)
            if (side !== "" && displays.length > 1 && displays.some(d => /^eDP-/.test(d.name))) {
                out.push({ kind: "header", name: "Laptop screen" })
                for (const [v, label, glyph] of [["below", "Below the display", "arrow-down"], ["above", "Above the display", "arrow-up"],
                                                 ["left", "Left of the display", "arrow-left"], ["right", "Right of the display", "arrow-right"],
                                                 ["auto", "Automatic", "monitor"]]) {
                    const cur = side === v
                    out.push({ kind: "side", value: v, name: label, glyph: cur ? "check" : glyph,
                               summary: cur ? "current" : v === "auto" ? "side by side" : undefined })
                }
            }
            for (const d of displays) {
                out.push({ kind: "header", name: "Scale" + (displays.length > 1 ? " · " + d.name + (d.desc !== "-" ? "  " + d.desc : "") : "") })
                for (const o of d.opts) {
                    const cur = Math.abs(o.value - d.scale) < 0.01
                    out.push({ kind: "scale", output: d.name, value: o.value, name: o.size, glyph: cur ? "check" : "monitor",
                               summary: (cur ? "current · " : "") + "scale " + +o.value.toFixed(2) })
                }
            }
            return out
        }
        if (level === "battery") {
            // The same as the top bar's battery menu: charge and state, then the details
            if (batt === null) return l.hint(p.hasBattery ? "Loading…" : "No battery in this computer")
            const b = battDetail
            const stateText = { discharging: "Discharging", charging: "Charging", "fully-charged": "Fully charged", "pending-charge": "Not charging" }[batt.state] || batt.state
            const rows = [{ kind: "stat", name: batt.percent + "%  " + stateText,
                            glyph: batt.state === "charging" ? "battery-charging" : batt.percent < 40 ? "battery-low" : batt.percent < 60 ? "battery-medium" : "battery-full",
                            summary: batt.timeText !== "" ? batt.timeText + (batt.state === "charging" ? " until full" : " remaining") : undefined }]
            if (b) {
                rows.push({ kind: "header", name: "Details" })
                for (const r of [["zap", "Power", b.watts > 0 ? b.watts + " W" : ""],
                                 ["thermometer", "Temperature", b.temp !== null ? b.temp + " °C" : ""],
                                 ["heart-pulse", "Health", b.health !== null ? b.health + "% · " + b.fullWh + " / " + b.designWh + " Wh" : ""],
                                 ["repeat", "Cycles", b.cycles !== null ? String(b.cycles) : ""],
                                 ["activity", "Voltage", b.volts !== null ? b.volts.toFixed(2) + " V" : ""],
                                 ["calendar", "Manufactured", b.made]])
                    if (r[2] !== "") rows.push({ kind: "stat", glyph: r[0], name: r[1], summary: r[2] })
            }
            return rows
        }
        return []
    }

    // The brightness and night light rows come from the root search too, so these work on any level
    function activate(it) {
        const l = launcher
        if (it.kind === "brightness") { l.shakeNow(); return true }   // ←/→ or the slider
        if (it.kind === "nightlight") {
            l.keepSelection()
            night = night === "on" ? "off" : "on"
            Quickshell.execDetached([scripts + "/nightlight", night])
            return true
        }
        if (it.kind === "side") {         // stays open like the scale rows; Hyprland reloads with the new arrangement
            l.keepSelection()
            side = it.value
            Quickshell.execDetached([scripts + "/display", "side", it.value])
            return true
        }
        if (it.kind === "scale") {        // stays open like the theme rows; Hyprland reloads with the new scale
            l.keepSelection()
            displays = displays.map(d => d.name === it.output ? Object.assign({}, d, { scale: it.value }) : d)
            Quickshell.execDetached([scripts + "/display", "scale", it.output, String(it.value)])
            return true
        }
        return false
    }

    // keepSelection: the new percentage rebuilds the rows, which would move the selection to the top
    function setBright(v) { launcher.keepSelection(); bright = v; pendingBright = v; if (!brightApply.running) brightApply.start() }
    // ←/→: to the next even step, like the brightness keys
    function stepBright(dir) {
        const pc = Math.round(bright * 100)
        const n = dir > 0 ? (Math.floor(pc / brightStep) + 1) * brightStep : (pc % brightStep === 0 ? pc - brightStep : Math.floor(pc / brightStep) * brightStep)
        setBright(Math.max(0, Math.min(100, n)) / 100)
    }
    Timer {
        id: brightApply; interval: 60
        onTriggered: {
            if (p.pendingBright < 0) return
            Quickshell.execDetached(["brightnessctl", "-c", "backlight", "-n2", "set", Math.round(p.pendingBright * 100) + "%"])
            p.pendingBright = -1
        }
    }

    // Display: outputs and their even scales
    Sh {
        id: displayProc
        script: '"$HOME/.config/hypr/scripts/display" list'
        onResult: text => {
            const first = p.displays === null
            p.displays = text.split("\n").map(l => l.split("\t")).filter(f => f.length >= 4).map(f => ({
                name: f[0], desc: f[1], scale: parseFloat(f[2]),
                opts: f.slice(3).map(o => { const [v, size] = o.split(":"); return { value: parseFloat(v), size: size.replace("×", " × ") } }) }))
            if (first && p.launcher.level === "display" && p.launcher.query === "") p.launcher.selectFirst()   // was the Loading… hint
        }
    }
    Sh {
        id: sideProc
        script: '"$HOME/.config/hypr/scripts/display" side'
        onResult: text => { p.launcher.keepSelection(); p.side = text.trim() }
    }
    // Brightness: read on entering and every 2 s while there (the brightness keys also work then),
    // not while the slider is held or a value is waiting to be applied
    Sh {
        id: brightProc
        // -c backlight: without a backlight brightnessctl would pick the first LED (a keyboard's Compose light)
        command: ["brightnessctl", "-m", "-c", "backlight"]
        onResult: text => {
            if (p.pendingBright >= 0) return
            const l = p.launcher
            const first = p.bright < 0
            const f = text.trim().split(",")
            const v = f.length >= 4 ? parseInt(f[3]) / 100 : -1
            if (v !== p.bright && !first) l.keepSelection()   // changed elsewhere (the brightness keys)
            p.bright = v
            // The rows above the scales appear only now: select the first one (the brightness row)
            if (first && p.bright >= 0 && l.level === "display" && l.query === "") l.selectFirst()
        }
    }
    Timer { interval: 2000; repeat: true; running: p.launcher !== null && p.launcher.open && p.launcher.level === "display"; onTriggered: brightProc.running = true }
    Sh {
        id: nightProc
        script: '"$HOME/.config/hypr/scripts/nightlight" status'
        onResult: text => { p.night = text.trim() }
    }
    // Battery: the machine's own battery, found like in topbar/scripts/status (MacBook: macsmc-battery);
    // read on entering and every 5 s while there
    Sh {
        id: battProc
        script: 'for d in /sys/class/power_supply/*; do [ "$(cat "$d/type")" = Battery ] && [ "$(cat "$d/scope" 2>/dev/null)" != Device ] &&
                 { upower -i "/org/freedesktop/UPower/devices/battery_$(basename "$d" | tr - _)"; break; }; done'
        onResult: text => {
            const g = re => { const r = text.match(re); return r ? r[1].trim() : "" }
            const fmt = (v, unit) => {
                const min = Math.round(parseFloat(v.replace(",", ".")) * (/hour/.test(unit) ? 60 : /second/.test(unit) ? 1 / 60 : 1))
                return Math.floor(min / 60) > 0 ? Math.floor(min / 60) + " h " + (min % 60) + " min" : min + " min"
            }
            const st = g(/state:\s*(\S+)/)
            const tte = text.match(/time to empty:\s*([\d.,]+)\s*(\w+)/)
            const ttf = text.match(/time to full:\s*([\d.,]+)\s*(\w+)/)
            if (st === "") { p.batt = null; return }
            p.launcher.keepSelection()
            p.batt = { percent: parseInt(g(/percentage:\s*(\d+)/)) || 0, state: st,
                       timeText: st === "discharging" && tte ? fmt(tte[1], tte[2]) : st === "charging" && ttf ? fmt(ttf[1], ttf[2]) : "" }
        }
    }
    // Once at start: a desktop has none, and its Battery page would only say so
    Sh {
        running: true
        script: 'for d in /sys/class/power_supply/*; do [ "$(cat "$d/type")" = Battery ] && [ "$(cat "$d/scope" 2>/dev/null)" != Device ] && { echo yes; break; }; done'
        onResult: text => { p.hasBattery = text.trim() === "yes" }
    }
    Sh {
        id: battDetailProc
        command: ["bash", "-c", "~/.config/topbar/scripts/sysinfo battery"]
        onResult: text => { try { p.battDetail = JSON.parse(text) } catch (e) { p.battDetail = null } }
    }
    Timer { interval: 5000; repeat: true; running: p.launcher !== null && p.launcher.open && p.launcher.level === "battery"; onTriggered: { battProc.running = true; battDetailProc.running = true } }
}
