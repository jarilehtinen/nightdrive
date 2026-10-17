import QtQuick
import Quickshell

// List of audio devices (PipeWire): kind "sink" = outputs (default), "source" = microphones. The selected device gets a check mark, a click changes the default device.
// Used in the Sound and Music menus. Refreshes every second, but only while `active` is true.
// Uses pw-dump like VolumeMenu (Quickshell's Pipewire module doesn't work with Pipewire 1.6).
// Outputs also list paired Bluetooth headphones that aren't connected: a click connects them and makes them the output
// (no need to go through the Bluetooth menu). Whether they're in range isn't known without a scan, so a failed connect shows an error.
Column {
    id: o
    width: parent ? parent.width : 300
    spacing: 2

    property bool active: true
    property string kind: "sink"      // "sink" | "source"
    readonly property string mediaClass: kind === "source" ? "Audio/Source" : "Audio/Sink"
    readonly property string defaultKey: kind === "source" ? "default.audio.source" : "default.audio.sink"
    property var sinkList: []
    // AirPlay speakers that refuse audio (Apple TV / HomePod OS 27 bug, docs/known-issues.md): checked live every 30 s,
    // so the error disappears by itself once Apple fixes it
    readonly property string airplayCheck: Quickshell.env("HOME") + "/.config/hypr/scripts/airplay-check"
    property var refused: []
    property real probedAt: 0
    property var btList: []          // paired, not connected Bluetooth audio devices: [{ mac, name }]
    property string btBusy: ""       // connecting to this MAC
    property string btFailed: ""     // the last connect to this MAC failed (off, in the case or out of range)
    property string btMakeDefault: "" // connected: make its sink the default as soon as it appears
    property int tick: 0

    function refresh() {
        dumpProc.running = true
        // bluetoothctl is slower than pw-dump: every 3 s is enough
        if (o.kind === "sink" && o.tick++ % 3 === 0 && !btProc.running) btProc.running = true
    }
    function btConnect(d) {
        if (o.btBusy !== "") return
        o.btBusy = d.mac; o.btFailed = ""
        btConnectProc.environment = { "MAC": d.mac }
        btConnectProc.running = true
    }
    onActiveChanged: if (active) refresh()
    Component.onCompleted: refresh()

    Timer { interval: 1000; repeat: true; running: o.active; onTriggered: o.refresh() }
    Timer { id: soon; interval: 150; onTriggered: o.refresh() }

    Sh {
        id: dumpProc
        command: ["pw-dump"]
        onResult: text => {
            let objs
            try { objs = JSON.parse(text) } catch (e) { return }
            let defName = ""
            for (const ob of objs) {
                if (ob.type !== "PipeWire:Interface:Metadata") continue
                for (const e of (ob.metadata || []))
                    if (e.key === o.defaultKey && e.value) defName = e.value.name
            }
            const sinks = []
            for (const ob of objs) {
                if (ob.type !== "PipeWire:Interface:Node") continue
                const p = (ob.info || {}).props || {}
                if (p["media.class"] !== o.mediaClass) continue
                if (/^easyeffects_/.test(p["node.name"])) continue   // EasyEffects' virtual device, not a real output
                sinks.push({ id: ob.id, name: p["node.description"] || p["node.name"], current: p["node.name"] === defName,
                             bt: /^bluez_/.test(p["node.name"]), node: p["node.name"] })
            }
            // The machine's own devices first (MacBook Pro …, then Built-in …), the rest alphabetically
            const rank = n => /^MacBook Pro/i.test(n) ? 0 : /^Built-in/i.test(n) ? 1 : 2
            sinks.sort((a, b) => rank(a.name) - rank(b.name) || a.name.localeCompare(b.name))
            o.sinkList = sinks
            if (o.btMakeDefault !== "") {
                const s = sinks.find(d => d.node.startsWith("bluez_output." + o.btMakeDefault.replace(/:/g, "_")))
                if (s) { Quickshell.execDetached(["wpctl", "set-default", String(s.id)]); o.btMakeDefault = ""; soon.start() }
            }
            const air = sinks.filter(d => /^raop_sink\./.test(d.node)).map(d => d.node)
            if (air.length > 0 && !probe.running && Date.now() - o.probedAt > 30000) {
                o.probedAt = Date.now()
                probe.command = [o.airplayCheck, "refused"].concat(air)
                probe.running = true
            }
        }
    }
    Sh {
        id: btProc
        // Audio Sink UUID = headphones / speakers
        script: 'bluetoothctl devices Paired | while read -r _ mac name; do\n' +
                '  info=$(bluetoothctl info "$mac")\n' +
                '  grep -q "Connected: no" <<<"$info" && grep -q "UUID: Audio Sink" <<<"$info" && echo "$mac|$name"\n' +
                'done'
        onResult: text => o.btList = text.split("\n").filter(l => l.indexOf("|") > 0)
                                       .map(l => ({ mac: l.slice(0, 17), name: l.slice(18) }))
                                       .sort((a, b) => a.name.localeCompare(b.name))
    }
    Sh {
        id: btConnectProc
        script: 'bluetoothctl connect "$MAC"'
        onResult: text => {
            if (btConnectProc.exitCode === 0) o.btMakeDefault = o.btBusy
            else o.btFailed = o.btBusy
            o.btBusy = ""
            btProc.running = true
            o.refresh()
        }
    }
    Sh {
        id: probe
        onResult: text => o.refused = text.split("\n").filter(l => l !== "")
    }

    Repeater {
        model: o.sinkList
        delegate: MenuRow {
            required property var modelData
            width: o.width
            active: modelData.current
            checkIcon: modelData.current ? "check" : ""
            label: modelData.name
            danger: o.refused.includes(modelData.node)
            detail: danger ? "no audio (Apple bug)" : ""
            icon: o.kind === "source" ? (modelData.bt || /head|buds|airpods/i.test(modelData.name) ? "headphones" : "mic")
                : modelData.bt || /head|buds|airpods/i.test(modelData.name) ? "headphones"
                : /macbook|built-in|laptop/i.test(modelData.name) ? "laptop"
                : /tv|display|monitor/i.test(modelData.name) ? "tv" : "speaker"
            onClicked: { Quickshell.execDetached(["wpctl", "set-default", String(modelData.id)]); soon.start() }
        }
    }
    Repeater {
        model: o.kind === "sink" ? o.btList : []
        delegate: MenuRow {
            required property var modelData
            width: o.width
            icon: "headphones"
            label: modelData.name
            busy: o.btBusy === modelData.mac
            danger: o.btFailed === modelData.mac
            detail: danger ? "not found" : "connect"
            onClicked: o.btConnect(modelData)
        }
    }
}
