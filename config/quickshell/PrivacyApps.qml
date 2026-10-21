import QtQuick
import Quickshell

// The apps using the microphone or the camera right now (topbar/scripts/privacy), for MicrophoneMenu and CameraMenu.
// Their bar icons show only while one is; MacBooks have a camera light but no microphone light.
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 10

    required property string key     // "mic" or "camera": the list in the script's JSON
    required property string title
    required property string icon
    property var apps: []

    Component.onCompleted: proc.running = true
    Timer { interval: 2000; repeat: true; running: true; onTriggered: proc.running = true }
    Sh {
        id: proc
        command: ["bash", "-c", "~/.config/topbar/scripts/privacy"]
        onResult: text => { try { m.apps = JSON.parse(text)[m.key] || [] } catch (e) {} }
    }

    MenuHeader { width: parent.width; title: m.title }

    Column {
        visible: m.apps.length > 0
        width: parent.width
        spacing: 2
        MenuSection { title: "In use by" }
        Repeater {
            model: m.apps
            delegate: MenuRow {
                required property string modelData
                width: parent.width
                height: 28
                interactive: false
                icon: m.icon
                label: modelData
            }
        }
    }

    MenuNote {
        visible: m.apps.length === 0
        text: "No app is using the " + m.title.toLowerCase() + "."
    }
}
