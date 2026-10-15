import QtQuick
import Quickshell

// Home Assistant: the pinned devices (a click turns one on/off or runs a scene), and the webapp. Devices are pinned in
// the launcher: ⌘Space › Home, Shift+Enter. Data: Home.qml (hypr/scripts/home-assistant).
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 8
    signal close()

    Component.onCompleted: { Home.check(); Home.refresh() }
    Timer { interval: 3000; repeat: true; running: true; onTriggered: Home.refresh() }

    MenuHeader { width: parent.width; title: "Home" }

    Text {
        visible: !Home.loaded || Home.error !== "" || Home.favorites.length === 0
        width: parent.width
        wrapMode: Text.Wrap
        text: !Home.loaded ? "Loading…"
            : Home.error !== "" ? Home.error
            : "No pinned devices. Pin them in the launcher: ⌘Space › Home, Shift+Enter on a device."
        color: Home.error !== "" ? Theme.danger : Theme.dim
        font { family: Theme.font; pixelSize: 12 }
    }

    Column {
        width: parent.width
        spacing: 2
        Repeater {
            model: Home.favorites
            delegate: MenuRow {
                required property var modelData
                width: m.width
                icon: Home.icon(modelData)
                iconFilled: Home.canToggle(modelData) && Home.isOn(modelData)
                label: modelData.name
                detail: [modelData.area, Home.detail(modelData)].filter(x => x).join(" · ")
                opacity: modelData.state === "unavailable" ? 0.5 : 1
                onClicked: Home.toggle(modelData)
            }
        }
    }

    Divider { padBottom: 6 }
    MenuRow {
        width: parent.width
        icon: "external-link"
        action: true
        label: "Open Home Assistant"
        onClicked: { Quickshell.execDetached([Home.bin, "open"]); m.close() }
    }
}
