import QtQuick
import Quickshell

// Sound: volume, mute and output selection, plus microphone volume, mute and selection.
// Uses wpctl and pw-dump (Quickshell's Pipewire module doesn't work with Pipewire 1.6).
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 10

    property real volume: 0
    property bool muted: false
    property real pending: -1
    property real micVolume: 0
    property bool micMuted: false
    property real micPending: -1
    signal close()

    function refresh() { volProc.running = true; micProc.running = true }
    function setVolume(v) {
        volume = v; pending = v
        if (!apply.running) apply.start()
    }
    function toggleMute() {
        muted = !muted
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        soon.start()
    }
    function setMicVolume(v) {
        micVolume = v; micPending = v
        if (!micApply.running) micApply.start()
    }
    function toggleMicMute() {
        micMuted = !micMuted
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
        soon.start()
    }
    Component.onCompleted: refresh()

    Timer { interval: 1000; repeat: true; running: true; onTriggered: m.refresh() }
    Timer { id: soon; interval: 150; onTriggered: m.refresh() }
    Timer {
        id: apply; interval: 60
        onTriggered: {
            if (m.pending >= 0) {
                Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", m.pending.toFixed(2)])
                m.pending = -1
            }
        }
    }

    Timer {
        id: micApply; interval: 60
        onTriggered: {
            if (m.micPending >= 0) {
                Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", m.micPending.toFixed(2)])
                m.micPending = -1
            }
        }
    }
    Sh {
        id: micProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        onResult: text => {
            if (micSlider.pressed || m.micPending >= 0) return
            const r = text.match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/)
            if (r) { m.micVolume = parseFloat(r[1]); m.micMuted = !!r[2] }
        }
    }
    Sh {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        onResult: text => {
            if (slider.pressed || m.pending >= 0) return
            const r = text.match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/)
            if (r) { m.volume = parseFloat(r[1]); m.muted = !!r[2] }
        }
    }
    MenuHeader { width: parent.width; title: "Sound"; showToggle: true; checked: !m.muted; onToggled: m.toggleMute() }   // toggle on = sound on

    Row {
        width: parent.width
        spacing: 12
        Text {
            id: volIcon
            width: 22
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: Icons.g(m.muted || m.volume === 0 ? "volume-x" : m.volume < 0.34 ? "volume" : m.volume < 0.67 ? "volume-1" : "volume-2")
            color: m.muted ? Theme.dim : Theme.text
            font { family: Icons.family; pixelSize: 18 }
            MouseArea { cursorShape: Qt.PointingHandCursor; anchors { fill: parent; margins: -6 } onClicked: m.toggleMute() }
        }
        Slider {
            id: slider
            width: parent.width - volIcon.width - pct.width - 24
            anchors.verticalCenter: parent.verticalCenter
            value: m.volume
            dimmed: m.muted
            onMoved: v => m.setVolume(v)
        }
        Text {
            id: pct
            width: 44
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Math.round(m.volume * 100) + "%"
            color: Theme.text
            font { family: Theme.font; pixelSize: 13 }
        }
    }

    Divider {}
    Text { text: "OUTPUT"; color: Theme.primary; font { family: Theme.font; pixelSize: 11; letterSpacing: 0.6 } }

    OutputList { width: parent.width }

    Divider {}
    MenuHeader { width: parent.width; title: "Microphone"; showToggle: true; checked: !m.micMuted; onToggled: m.toggleMicMute() }

    Row {
        width: parent.width
        spacing: 12
        Text {
            id: micIcon
            width: 22
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: Icons.g(m.micMuted ? "mic-off" : "mic")
            color: m.micMuted ? Theme.dim : Theme.text
            font { family: Icons.family; pixelSize: 18 }
            MouseArea { cursorShape: Qt.PointingHandCursor; anchors { fill: parent; margins: -6 } onClicked: m.toggleMicMute() }
        }
        Slider {
            id: micSlider
            width: parent.width - micIcon.width - micPct.width - 24
            anchors.verticalCenter: parent.verticalCenter
            value: m.micVolume
            dimmed: m.micMuted
            onMoved: v => m.setMicVolume(v)
        }
        Text {
            id: micPct
            width: 44
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Math.round(m.micVolume * 100) + "%"
            color: Theme.text
            font { family: Theme.font; pixelSize: 13 }
        }
    }

    Divider {}
    Text { text: "INPUT SOURCE"; color: Theme.primary; font { family: Theme.font; pixelSize: 11; letterSpacing: 0.6 } }

    OutputList { width: parent.width; kind: "source" }

    Divider {}
    MenuRow {
        width: parent.width
        icon: "settings"
        action: true
        label: "Sound settings…"
        onClicked: { Quickshell.execDetached(["pavucontrol"]); m.close() }
    }
}
