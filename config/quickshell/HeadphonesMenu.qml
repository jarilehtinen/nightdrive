import QtQuick
import Quickshell

// Headphones (shown in the bar only while Bluetooth headphones are connected): select as output and pick the EasyEffects EQ preset
// (the connected headphones' own presets, see config/easyeffects/build-presets) and their noise cancelling state.
// Battery: AirPods per pod and case (hypr/scripts/headphones-ctl), other headphones the level BlueZ reports.
// AirPods settings… opens their own settings (AirPodsSettings.qml).
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
        "Adaptive":         { icon: "sparkles" },
        "Transparency":     { icon: "ear" },
        "Passive":          { icon: "mic-audio-lines" }
    })
    // the measured modes, in the order above
    readonly property var ancModes: (info.ancModes || []).slice().sort((a, b) => {
        const k = Object.keys(ancInfo), ia = k.indexOf(a), ib = k.indexOf(b)
        return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib) || a.localeCompare(b)
    })
    property var info: ({})
    property real maxShown: -1   // while dragging the Max volume slider (saved on release)
    readonly property bool eqOn: !!info.preset && info.preset !== "off"
    readonly property var pods: (info.airpods && info.airpods.pods) || ({})
    readonly property var podRows: ["left", "right", "case"].filter(k => pods[k]).map(k => Object.assign({ key: k }, pods[k]))
    readonly property bool hasBattery: podRows.length > 0 || /^\d+$/.test(info.battery || "")
    function podStatus(p) {
        if (p.key === "case") return p.stale ? "earlier" : p.charging ? "charging" : ""
        return { ear: "in ear", out: "out", case: "in case" }[p.where] || ""
    }
    signal close()

    function refresh() { infoProc.running = true }
    function run(args) {
        setProc.command = [m.eq].concat(args)
        setProc.running = true
    }
    Component.onCompleted: refresh()
    // Every 2 s; every 0.4 s while a picked listening mode is on its way to the headphones
    Timer { interval: m.ancPending !== "" ? 400 : 2000; repeat: true; running: true; onTriggered: m.refresh() }
    // The listening mode picked in the menu until the headphones report it (busy dots on its row); gives up after 10 s
    property string ancPending: ""
    Timer { id: ancGiveUp; interval: 10000; onTriggered: m.ancPending = "" }

    Sh {
        id: infoProc
        command: [m.eq, "info"]
        onResult: text => {
            try { m.info = JSON.parse(text) } catch (e) {}
            if (m.info.anc === m.ancPending) m.ancPending = ""
        }
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
        detail: m.info.codec || ""
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

    Divider { visible: m.hasBattery }
    MenuHeader { visible: m.hasBattery; width: parent.width; title: "Battery" }
    Column {
        visible: m.hasBattery
        width: parent.width
        spacing: 10
        topPadding: 2; bottomPadding: 4
        Repeater {
            model: m.podRows
            delegate: BatteryBar {
                required property var modelData
                width: parent.width
                label: ({ left: "Left", right: "Right", case: "Case" })[modelData.key]
                level: modelData.level
                charging: modelData.charging
                stale: !!modelData.stale
                status: m.podStatus(modelData)
            }
        }
        BatteryBar {
            visible: m.podRows.length === 0
            width: parent.width
            level: parseInt(m.info.battery) || 0
            status: level < 20 ? "low" : ""
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
    // The headphones' listening mode: Sony headphones and AirPods switch to it and report it (hypr/scripts/headphones-ctl); for others it only
    // tells the EQ which measurement to use (headphones measured in several modes, see config/easyeffects/headphones.example.tsv)
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
                busy: m.ancPending === modelData
                onClicked: if (!active && m.ancPending === "") { m.ancPending = modelData; ancGiveUp.restart(); m.run(["anc", modelData]) }
            }
        }
    }
    Text {   // headphones that can't tell their mode (headphones-ctl handles Sony's and AirPods': the list then follows them)
        visible: m.ancModes.length > 1 && !m.info.ancControlled
        width: parent.width
        wrapMode: Text.Wrap
        text: "Pick the mode set on the headphones: the EQ follows it."
        color: Theme.dim
        font { family: Theme.font; pixelSize: 11 }
    }
    Text {
        visible: !!m.info.sink && !m.info.default
        width: parent.width
        wrapMode: Text.Wrap
        text: "Sound is playing from another output. The EQ takes effect when the headphones are selected."
        color: Theme.dim
        font { family: Theme.font; pixelSize: 11 }
    }

    // Max volume per headphones: switching to them (e.g. from a Mac) at full volume can be painfully loud.
    // hypr/scripts/bt-audio-follow turns any louder volume down to it.
    Divider {}
    MenuHeader { width: parent.width; title: "Max volume" }
    Row {
        width: parent.width
        spacing: 12
        readonly property real value: m.maxShown >= 0 ? m.maxShown : (m.info.maxVolume || 100) / 100
        Text {
            id: maxIcon
            width: 22
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: Icons.g("volume-2")
            color: Theme.dim
            font { family: Icons.family; pixelSize: 18 }
        }
        Slider {
            width: parent.width - maxIcon.width - maxPct.width - 24
            anchors.verticalCenter: parent.verticalCenter
            value: parent.value
            onMoved: v => m.maxShown = Math.max(0.1, Math.round(v * 20) / 20)   // steps of 5 %, at least 10 %
            onPressedChanged: if (!pressed && m.maxShown >= 0) {
                m.run(["max-volume", String(Math.round(m.maxShown * 100))])
                m.info = Object.assign({}, m.info, { maxVolume: Math.round(m.maxShown * 100) })
                m.maxShown = -1
            }
        }
        Text {
            id: maxPct
            width: 44
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: parent.value >= 1 ? "Off" : Math.round(parent.value * 100) + "%"
            color: Theme.text
            font { family: Theme.font; pixelSize: 13 }
        }
    }

    Divider {}
    MenuRow {
        visible: !!m.info.airpods
        width: parent.width
        icon: "headphones"
        action: true
        label: "AirPods settings…"
        onClicked: { Quickshell.execDetached(["qs", "ipc", "call", "airpods", "open"]); m.close() }
    }
    MenuRow {
        width: parent.width
        icon: "sliders-horizontal"
        action: true
        label: "EasyEffects…"
        onClicked: { Quickshell.execDetached(["easyeffects"]); m.close() }
    }
}
