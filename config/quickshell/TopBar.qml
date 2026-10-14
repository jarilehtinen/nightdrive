pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The top bar's data (Bar.qml draws it). Everything is read from files that are watched, so edits show at once:
//   ~/.config/topbar/modules.jsonc (+ local.modules.jsonc)   the modules, in order
//   ~/.config/topbar/adjust.conf   (+ local.adjust.conf)     icon sizes and positions, the text size
//   ~/.cache/nightdrive/bar.json                              colours (hypr/scripts/bar-style)
// A module's state comes from its status command (one line of JSON {icon, text, class}); icons are SVGs from
// topbar/scripts/icon, cached here by name.
Singleton {
    id: tb
    readonly property string dir: Quickshell.env("HOME") + "/.config/topbar"

    // --- Modules ---
    property var publicModules: []
    property var localModules: []
    readonly property var modules: localModules.concat(publicModules)
    property var states: ({})          // name -> {icon, text, class}
    function parseJsonc(t) {
        try { return JSON.parse(t.split("\n").filter(l => !/^\s*\/\//.test(l)).join("\n")) } catch (e) { return null }
    }
    FileView {
        path: tb.dir + "/modules.jsonc"; watchChanges: true; onFileChanged: reload()
        onLoaded: tb.publicModules = tb.parseJsonc(text()) || tb.publicModules
    }
    FileView {
        path: tb.dir + "/local.modules.jsonc"; watchChanges: true; onFileChanged: reload(); printErrors: false   // optional (an overlay)
        onLoaded: tb.localModules = tb.parseJsonc(text()) || tb.localModules
        onLoadFailed: tb.localModules = []
    }

    property var runners: ({})
    Instantiator {
        model: tb.modules
        delegate: Scope {
            id: runner
            required property var modelData
            readonly property string name: modelData.name
            function run() { if (!proc.running) proc.running = true }
            Component.onCompleted: tb.runners[name] = runner
            Component.onDestruction: if (tb.runners[name] === runner) delete tb.runners[name]
            Process {
                id: proc
                command: ["bash", "-c", runner.modelData.status || ("~/.config/topbar/scripts/status " + runner.name)]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const line = text.trim().split("\n").pop() || ""
                        if (JSON.stringify(tb.states[runner.name]) === line) return
                        let s = null
                        try { s = JSON.parse(line) } catch (e) {}
                        const n = Object.assign({}, tb.states); n[runner.name] = s; tb.states = n
                    }
                }
            }
            Timer {
                interval: (runner.modelData.interval || 5) * 1000
                running: true; repeat: true; triggeredOnStart: true
                onTriggered: runner.run()
            }
        }
    }
    // Updates one module now, or all of them ("": also re-reads the icons, e.g. after adding an SVG)
    function refresh(name) {
        if (!name) svgs = ({})
        for (const k in runners) if (!name || k === name) runners[k].run()
    }
    // Right / middle click: the module's command, then an update of the module
    function run(cmd, name) {
        const p = cmdProc.createObject(tb, { command: ["bash", "-c", cmd], name: name })
        p.running = true
    }
    Component {
        id: cmdProc
        Process {
            property string name
            onExited: { tb.refresh(name); destroy() }
        }
    }

    // --- Sizes: rows "element size y"; text = every text, icon = icons without a row of their own ---
    property var sizesPublic: ({})
    property var sizesLocal: ({})
    function parseSizes(t) {
        const out = {}
        for (const line of t.split("\n")) {
            const f = line.split("#")[0].trim().split(/\s+/)
            if (f.length >= 3 && !isNaN(parseFloat(f[1]))) out[f[0]] = { size: parseFloat(f[1]), y: parseFloat(f[2]) || 0 }
        }
        return out
    }
    FileView {
        path: tb.dir + "/adjust.conf"; watchChanges: true; onFileChanged: reload()
        onLoaded: tb.sizesPublic = tb.parseSizes(text())
    }
    FileView {
        path: tb.dir + "/local.adjust.conf"; watchChanges: true; onFileChanged: reload(); printErrors: false
        onLoaded: tb.sizesLocal = tb.parseSizes(text())
        onLoadFailed: tb.sizesLocal = ({})
    }
    function size(el) {
        return sizesLocal[el] || sizesPublic[el] || (el === "text" ? { size: 13, y: 0 } : sizesPublic.icon || { size: 16, y: 0 })
    }

    // --- Colours (bar-style); defaults = white icons on black ---
    property var col: ({})
    FileView {
        path: Quickshell.env("HOME") + "/.cache/nightdrive/bar.json"; watchChanges: true; onFileChanged: reload()
        onLoaded: { try { tb.col = JSON.parse(text()) } catch (e) {} }
    }
    function c(k) {
        return col[k] || { bg: "#ff000000", fg: "#d9ffffff", dim: "#8cffffff", off: "#57ffffff", hlBg: "#4db17bcb",
                           hlFg: "#ffffff", actBg: "#40c071eb", wsBg: "#4db17bcb" }[k]
    }

    // --- Icons: SVG text by name ("" = not found); fetched once, then cached ---
    property var svgs: ({})
    property var loading: ({})
    function svg(ref) {
        if (!ref) return ""
        if (svgs[ref] !== undefined) return svgs[ref]
        const g = ref.match(/^gauge@(\d+)$/)
        if (g) return gauge(Math.min(100, parseInt(g[1])))
        if (!loading[ref]) {
            loading[ref] = true
            iconProc.createObject(tb, { ref: ref }).running = true
        }
        return ""
    }
    Component {
        id: iconProc
        Process {
            id: ip
            property string ref
            command: [tb.dir + "/scripts/icon", ref]
            stdout: StdioCollector {
                onStreamFinished: {
                    const n = Object.assign({}, tb.svgs); n[ip.ref] = text.indexOf("<svg") >= 0 ? text : ""; tb.svgs = n
                    delete tb.loading[ip.ref]
                    ip.destroy()
                }
            }
        }
    }
    // gauge@<percent>: Lucide's gauge with its needle pointing at the percentage (the Claude module's usage). The dial is
    // the arc around (12, 14) from lower left (0 %, 210°) over the top to lower right (100 %, -30°).
    function gauge(p) {
        const a = (210 - 2.4 * p) * Math.PI / 180, len = 5.66
        const x = (12 + len * Math.cos(a)).toFixed(2), y = (14 - len * Math.sin(a)).toFixed(2)
        return '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" '
             + 'stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 14 L' + x + ' ' + y + '"/>'
             + '<path d="M3.34 19a10 10 0 1 1 17.32 0"/></svg>'
    }
    // An SVG drawn in one colour: currentColor -> the colour (opaque; the caller applies its alpha as opacity)
    function iconUrl(ref, color) {
        const s = svg(ref)
        if (!s) return ""
        const rgb = Qt.rgba(color.r, color.g, color.b, 1).toString()
        return "data:image/svg+xml;utf8," + encodeURIComponent(s.replace(/currentColor/g, rgb))
    }
}
