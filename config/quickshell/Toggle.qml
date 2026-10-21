import QtQuick

// An on/off switch: MenuHeader's (Wi-Fi, Bluetooth, Microphone) and a settings row's (Display › Night light).
// navSelected: keyboard focus on it turns the whole switch violet.
Rectangle {
    id: t
    property bool checked: false
    property bool navSelected: false
    signal toggled()
    width: 34; height: 20; radius: 10
    color: navSelected ? Theme.primary : (checked ? Theme.accent : Theme.border)
    Rectangle {
        width: 14; height: 14; radius: 7; y: 3
        x: t.checked ? 17 : 3
        color: t.checked ? Theme.bg : Theme.text
        Behavior on x { NumberAnimation { duration: 120 } }
    }
    MouseArea { cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: t.toggled() }
}
