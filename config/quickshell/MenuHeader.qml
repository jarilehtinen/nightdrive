import QtQuick

// Title, an optional subtitle on the right (smaller, dimmed: e.g. the Claude plan) and an optional on/off toggle on the right edge.
Item {
    id: h
    property string title: ""
    property string subtitle: ""
    property bool showToggle: false
    property bool checked: false
    signal toggled()
    property bool navSelected: false   // selected during keyboard navigation
    readonly property bool navEnabled: showToggle
    function navActivate() { if (showToggle) toggled() }

    height: 26
    Text {
        id: titleText
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: h.title.toUpperCase()
        color: Theme.primary
        font { family: Theme.font; pixelSize: 12; weight: Font.Medium; letterSpacing: 0.6 }
    }
    Text {
        visible: h.subtitle !== ""
        anchors { right: parent.right; rightMargin: h.showToggle ? 44 : 0; baseline: titleText.baseline }
        text: h.subtitle.toUpperCase()
        color: Theme.dim
        font { family: Theme.font; pixelSize: 10; letterSpacing: 0.6 }
    }
    Rectangle {
        visible: h.showToggle
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 34; height: 20; radius: 10
        color: h.navSelected ? Theme.primary : (h.checked ? Theme.accent : Theme.border)   // keyboard focus: the whole toggle turns violet
        Rectangle {
            width: 14; height: 14; radius: 7; y: 3
            x: h.checked ? 17 : 3
            color: h.checked ? Theme.bg : Theme.text
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        MouseArea { cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: h.toggled() }
    }
}
