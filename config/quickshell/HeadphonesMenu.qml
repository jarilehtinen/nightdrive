import QtQuick
import Quickshell

// Headphones (shown in the bar only while Bluetooth headphones are connected): select as output and pick the EasyEffects EQ preset
// (the connected headphones' own presets, see config/easyeffects/build-presets) and their noise cancelling state.
// Info and changes: ~/.config/topbar/scripts/eq (info / set / toggle). The preset is saved as the headphones' autoload profile.
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 8

    readonly property string eq: Quickshell.env("HOME") + "/.config/topbar/scripts/eq"
    readonly property var presetInfo: ({
        "Neutral": { icon: "audio-lines", detail: "AutoEq" },
        "Bass":    { icon: "speaker",       detail: "more bass" },
        "Voice":   { icon: "speech",      detail: "podcasts, calls" }
    })
    readonly property var ancInfo: ({
        "Noise cancelling": { icon: "ear-off" },
        "Transparency":     { icon: "ear" },
        "Passive":          { icon: "mic-audio-lines" }
    })
    // the measured modes, in the order above
    readonly property var ancModes: (info.ancModes || []).slice().sort((a, b) => {
        const k = Object.keys(ancInfo), ia = k.indexOf(a), ib = k.indexOf(b)
        return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib) || a.localeCompare(b)
    })
    property var info: ({})
    readonly property bool eqOn: !!info.preset && info.preset !== "off"
    signal close()

    function refresh() { infoProc.running = true }
    function run(args) {
        setProc.command = [m.eq].concat(args)
        setProc.running = true
    }
    Component.onCompleted: refresh()
    Timer { interval: 2000; repeat: true; running: true; onTriggered: m.refresh() }

    Sh {
        id: infoProc
        command: [m.eq, "info"]
        onResult: text => { try { m.info = JSON.parse(text) } catch (e) {} }
    }
    Sh {
        id: setProc
        onResult: () => { m.refresh(); TopBar.refresh("headphones") }
    }

    MenuHeader { width: parent.width; title: "Headphones" }

    MenuRow {
        width: parent.width
        icon: "headphones"
        label: m.info.name || "Not connected"
        detail: [m.info.battery ? m.info.battery + "%" : "", m.info.codec || ""].filter(s => s).join(" · ")
        active: !!m.info.default
        checkIcon: m.info.default ? "check" : ""
        hoverCheckIcon: m.info.default ? "unplug" : ""
        // Already the output: a click disconnects the headphones (the MAC is in the sink name, bluez_output.C4_6E_….1).
        // Otherwise it makes them the output.
        onClicked: {
            if (!m.info.sink) return
            const mac = (m.info.sink.match(/^bluez_output\.([0-9A-F_]{17})/) || [])[1]
            if (m.info.default && mac) { Quickshell.execDetached(["bluetoothctl", "disconnect", mac.replace(/_/g, ":")]); m.close() }
            else { Quickshell.execDetached(["pactl", "set-default-sink", m.info.sink]); m.refresh() }
        }
    }

    Divider {}
    MenuHeader { width: parent.width; title: "Equalizer"; showToggle: true; checked: m.eqOn; onToggled: m.run(["toggle"]) }

    Column {
        width: parent.width
        spacing: 2
        Repeater {
            // known presets first in this order, others (made in EasyEffects) after them
            model: (m.info.presets || []).slice().sort((a, b) => {
                const k = Object.keys(m.presetInfo), ia = k.indexOf(a), ib = k.indexOf(b)
                return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib) || a.localeCompare(b)
            })
            delegate: MenuRow {
                required property string modelData
                width: parent.width
                icon: (m.presetInfo[modelData] || { icon: "sliders-horizontal" }).icon
                label: modelData
                detail: (m.presetInfo[modelData] || { detail: "" }).detail
                active: m.info.preset === modelData
                checkIcon: active ? "check" : ""
                onClicked: m.run(["set", active ? "Off" : modelData])   // clicking the selected one turns the EQ off
            }
        }
    }
    // The headphones' listening mode (noise cancelling, transparency …) can't be read over Bluetooth: picking it here tells the EQ which measurement
    // to use (only for headphones measured in several modes, see config/easyeffects/headphones.example.tsv)
    Divider { visible: m.ancModes.length > 1 }
    MenuHeader { visible: m.ancModes.length > 1; width: parent.width; title: "Listening mode" }
    Column {
        visible: m.ancModes.length > 1
        width: parent.width
        spacing: 2
        Repeater {
            model: m.ancModes
            delegate: MenuRow {
                required property string modelData
                width: parent.width
                icon: (m.ancInfo[modelData] || { icon: "headphones" }).icon
                label: modelData
                active: m.info.anc === modelData
                checkIcon: active ? "check" : ""
                onClicked: if (!active) m.run(["anc", modelData])
            }
        }
    }
    Text {
        visible: !!m.info.sink && !m.info.default
        width: parent.width
        wrapMode: Text.Wrap
        text: "Sound is playing from another output. The EQ takes effect when the headphones are selected."
        color: Theme.dim
        font { family: Theme.font; pixelSize: 11 }
    }

    Divider {}
    MenuRow {
        width: parent.width
        icon: "sliders-horizontal"
        action: true
        label: "EasyEffects…"
        onClicked: { Quickshell.execDetached(["easyeffects"]); m.close() }
    }
}
