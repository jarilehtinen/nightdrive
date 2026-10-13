import QtQuick
import Quickshell

// Machine meters: CPU, memory, temperatures and the heaviest processes (data: waybar/scripts/sysinfo menu).
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
        command: ["bash", "-c", "~/.config/waybar/scripts/sysinfo menu"]
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
        Text {
            visible: note !== ""
            text: note; color: Theme.dim
            font { family: Theme.font; pixelSize: 11 }
        }
    }

    Meter {
        visible: m.d !== null
        title: "CPU"
        value: m.d ? m.d.cpu + " %" : ""
        frac: m.d ? m.d.cpu / 100 : 0
        note: m.d ? m.d.cores + " cores · avg " + m.d.freq + " MHz · load " + m.d.load.join("  ") : ""
    }
    Meter {
        visible: m.d !== null
        title: "Memory"
        value: m.d ? m.gb(m.d.memUsed) + " / " + m.gb(m.d.memTotal) + " GB" : ""
        frac: m.d ? m.d.memUsed / m.d.memTotal : 0
        note: m.d && m.d.swapUsed > 0 ? "Swap " + m.mb(m.d.swapUsed) + " / " + m.mb(m.d.swapTotal) : ""
    }

    Divider {}

    Text {
        visible: m.d !== null
        text: "TEMPERATURES"
        color: Theme.primary
        font { family: Theme.font; pixelSize: 11; letterSpacing: 0.6 }
    }
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
                icon: "thermometer"
                label: modelData.label
                detail: modelData.c + " °C"
                danger: modelData.c >= 70
            }
        }
        MenuRow {
            visible: m.d !== null && m.d.batStatus !== ""
            width: parent.width
            height: 28
            icon: "battery"
            label: "Charge"
            detail: m.d ? m.d.batPct + " % · " + m.d.batStatus.toLowerCase() + (m.d.watts > 0 ? " · " + m.d.watts + " W" : "") : ""
        }
    }

    Divider {}

    Row {
        spacing: 8
        Text { text: "TOP PROCESSES"; color: Theme.primary; font { family: Theme.font; pixelSize: 11; letterSpacing: 0.6 } }
        Text { text: "(CPU, 1 core = 100 %)"; color: Theme.dim; font { family: Theme.font; pixelSize: 11 } }
    }
    Column {
        width: parent.width
        spacing: 2
        Repeater {
            model: m.d ? m.d.top : []
            delegate: MenuRow {
                required property var modelData
                width: parent.width
                height: 28
                label: modelData.name
                detail: modelData.cpu.toFixed(1) + " %  ·  " + m.mb(modelData.rss)
                active: modelData.cpu >= 50
            }
        }
    }
}
