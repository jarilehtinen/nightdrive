import QtQuick

// Horizontal slider, value 0..1.
Item {
    id: s
    property real value: 0
    property bool dimmed: false
    property color trackColor: Theme.border   // the unfilled part; on a selected row (Theme.sel) it needs to be darker
    readonly property bool pressed: area.pressed
    signal moved(real v)

    height: 20
    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 6; radius: 3
        color: s.trackColor
        Rectangle {
            width: parent.width * Math.min(1, Math.max(0, s.value))
            height: parent.height; radius: 3
            color: s.dimmed ? Theme.dim : Theme.accent
        }
        Rectangle {
            x: parent.width * Math.min(1, Math.max(0, s.value)) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 7
            color: Theme.text
        }
    }
    MouseArea {
        cursorShape: Qt.PointingHandCursor
        id: area
        anchors.fill: parent
        function setV(mx) { s.moved(Math.max(0, Math.min(1, mx / track.width))) }
        onPressed: mouse => setV(mouse.x)
        onPositionChanged: mouse => { if (pressed) setV(mouse.x) }
    }
}
