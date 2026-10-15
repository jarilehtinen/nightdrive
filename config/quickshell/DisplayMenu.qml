import QtQuick
import Quickshell

// Display: screen brightness (brightnessctl), night light (hypr/scripts/nightlight) and the scale of each output
// (hypr/scripts/display: only scales the panel divides evenly, shown as the resulting desktop size).
// The launcher's Settings › Display has the same settings.
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 10

    property real screen: -1         // -1 = no display backlight (a VM)
    property real pending: -1
    property string night: ""        // on | off
    property var displays: []        // [{ name, desc, scale, opts: [{ value, size }] }]
    signal close()

    function refresh() { briProc.running = true; nightProc.running = true }
    Component.onCompleted: { refresh(); displayProc.running = true }
    Timer { interval: 3000; repeat: true; running: true; onTriggered: m.refresh() }

    Timer {
        id: apply; interval: 60
        onTriggered: {
            if (m.pending < 0) return
            Quickshell.execDetached(["brightnessctl", "-c", "backlight", "-n2", "set", Math.round(m.pending * 100) + "%"])
            m.pending = -1
        }
    }
    Sh {
        id: briProc
        // -c backlight: without a backlight brightnessctl would pick the first LED (a keyboard's Compose light)
        command: ["brightnessctl", "-m", "-c", "backlight"]
        onResult: text => {
            if (slider.pressed || m.pending >= 0) return
            const f = text.trim().split(",")
            m.screen = f.length >= 4 ? parseInt(f[3]) / 100 : -1
        }
    }
    Sh {
        id: nightProc
        script: '"$HOME/.config/hypr/scripts/nightlight" status'
        onResult: text => { m.night = text.trim() }
    }
    Sh {
        id: displayProc
        script: '"$HOME/.config/hypr/scripts/display" list'
        onResult: text => {
            m.displays = text.split("\n").map(l => l.split("\t")).filter(f => f.length >= 4).map(f => ({
                name: f[0], desc: f[1], scale: parseFloat(f[2]),
                opts: f.slice(3).map(o => { const [v, size] = o.split(":"); return { value: parseFloat(v), size: size.replace("×", " × ") } }) }))
        }
    }

    MenuHeader { width: parent.width; title: "Display" }

    MenuSection { visible: m.screen >= 0; title: "Brightness" }
    Row {
        visible: m.screen >= 0
        width: parent.width
        spacing: 12
        Text {
            id: sunIcon
            width: 22
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: Icons.g("sun")
            color: Theme.text
            font { family: Icons.family; pixelSize: 18 }
        }
        Slider {
            id: slider
            width: parent.width - sunIcon.width - pct.width - 24
            anchors.verticalCenter: parent.verticalCenter
            value: Math.max(0, m.screen)
            onMoved: v => { m.screen = v; m.pending = v; if (!apply.running) apply.start() }
        }
        Text {
            id: pct
            width: 44
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Math.round(Math.max(0, m.screen) * 100) + "%"
            color: Theme.text
            font { family: Theme.font; pixelSize: 13 }
        }
    }
    MenuRow {
        visible: m.night !== ""
        width: parent.width
        icon: "moon"
        label: "Night light"
        padded: true
        active: m.night === "on"
        checkIcon: m.night === "on" ? "check" : ""
        onClicked: {
            m.night = m.night === "on" ? "off" : "on"
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/nightlight", m.night])
        }
    }

    Divider { visible: m.displays.length > 0 }
    Repeater {
        model: m.displays
        delegate: Column {
            required property var modelData
            readonly property var d: modelData
            width: m.width
            spacing: 2
            MenuSection { title: "Scale" + (m.displays.length > 1 ? " · " + d.name : "") }
            Repeater {
                model: d.opts
                delegate: MenuRow {
                    required property var modelData
                    readonly property bool cur: Math.abs(modelData.value - d.scale) < 0.01
                    width: parent.width
                    icon: "monitor"
                    label: modelData.size
                    detail: "scale " + +modelData.value.toFixed(2)
                    active: cur
                    checkIcon: cur ? "check" : ""
                    onClicked: {
                        if (cur) return
                        // Shown as chosen at once; Hyprland reloads with the new scale and the menu follows
                        m.displays = m.displays.map(x => x.name === d.name ? Object.assign({}, x, { scale: modelData.value }) : x)
                        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/display", "scale", d.name, String(modelData.value)])
                    }
                }
            }
        }
    }
}
