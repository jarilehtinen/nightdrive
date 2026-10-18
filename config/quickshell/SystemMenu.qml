import QtQuick
import Quickshell

// Machine meters: CPU, memory, temperatures and the heaviest processes (data: topbar/scripts/sysinfo menu).
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 10

    property var d: null
    readonly property int preferredWidth: 340

    function refresh() { proc.running = true }
    function gb(b) { return (b / 1073741824).toFixed(1) }
    function mb(b) { return b >= 1073741824 ? gb(b) + " GB" : Math.round(b / 1048576) + " MB" }
    function color(pct) { return pct >= 85 ? Theme.danger : (pct >= 60 ? Theme.caution : Theme.accent) }
    Component.onCompleted: refresh()
    Timer { interval: 2000; repeat: true; running: true; onTriggered: m.refresh() }

    Sh {
        id: proc
        command: ["bash", "-c", "~/.config/topbar/scripts/sysinfo menu"]
        onResult: text => { try { m.d = JSON.parse(text) } catch (e) {} }
    }

    MenuHeader { width: parent.width; title: "System" }

    component Meter: Column {
        property string title: ""
        property string value: ""
        property real frac: 0
        property string note: ""
        width: m.width
        spacing: 5
        Item {
            width: parent.width; height: 18
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: title.toUpperCase(); color: Theme.text
                font { family: Theme.font; pixelSize: 13; letterSpacing: 0.6 }
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: value; color: m.color(frac * 100)
                font { family: Theme.font; pixelSize: 13; bold: true }
            }
        }
        Rectangle {
            width: parent.width; height: 6; radius: 3; color: Theme.border
            Rectangle {
                width: parent.width * Math.min(1, Math.max(0, frac)); height: parent.height; radius: 3
                color: m.color(frac * 100)
            }
        }
        MenuNote { text: note }
    }

    Meter {
        visible: m.d !== null
        title: "CPU"
        value: m.d ? m.d.cpu + "%" : ""
        frac: m.d ? m.d.cpu / 100 : 0
        // No-break spaces inside each part: a line too long for the menu wraps between the parts, not inside the load
        note: m.d ? m.d.cores + "\u00a0cores" + (m.d.freq > 0 ? " · avg\u00a0" + m.d.freq + "\u00a0MHz" : "")   // no cpufreq in a VM
                    + " · load\u00a0" + m.d.load.join("\u00a0\u00a0") : ""
    }
    Meter {
        visible: m.d !== null
        title: "Memory"
        value: m.d ? m.gb(m.d.memUsed) + " / " + m.gb(m.d.memTotal) + " GB" : ""
        frac: m.d ? m.d.memUsed / m.d.memTotal : 0
        note: m.d && m.d.swapUsed > 0 ? "Swap " + m.mb(m.d.swapUsed) + " / " + m.mb(m.d.swapTotal) : ""
    }

    Divider { visible: m.d !== null && m.d.temps.length > 0 }   // no sensors in a VM: the whole section is left out

    MenuSection { visible: m.d !== null && m.d.temps.length > 0; title: "Temperatures" }
    Column {
        visible: m.d !== null
        width: parent.width
        spacing: 2
        Repeater {
            model: m.d ? m.d.temps : []
            delegate: MenuRow {
                required property var modelData
                width: parent.width
                height: 28
                interactive: false
                icon: "thermometer"
                label: modelData.label
                detail: modelData.c + " °C"
                danger: modelData.c >= 70
            }
        }
    }

    Divider {}

    MenuSection { title: "Top processes"; subtitle: "CPU, 1 core = 100 %" }
    Column {
        width: parent.width
        spacing: 2
        Repeater {
            model: m.d ? m.d.top : []
            delegate: MenuRow {
                required property var modelData
                width: parent.width
                height: 28
                interactive: false
                label: modelData.name
                detail: modelData.cpu.toFixed(1) + "%  ·  " + m.mb(modelData.rss)
                active: modelData.cpu >= 50
            }
        }
    }
}
