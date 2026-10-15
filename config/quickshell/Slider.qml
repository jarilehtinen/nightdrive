import QtQuick

// Horizontal slider, value 0..1.
Item {
    id: s
    property real value: 0
    property bool dimmed: false
    property color trackColor: Theme.border   // the unfilled part; on a selected row (Theme.sel) it needs to be darker
    readonly property bool pressed: area.pressed
    // While held, the knob follows the mouse even if `value` lags behind (or the owner holds back updates during a drag)
    property real dragValue: -1
    readonly property real shown: area.pressed && dragValue >= 0 ? dragValue : value
    signal moved(real v)

    height: 20
    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 6; radius: 3
        color: s.trackColor
        Rectangle {
            width: parent.width * Math.min(1, Math.max(0, s.shown))
            height: parent.height; radius: 3
            color: s.dimmed ? Theme.dim : Theme.accent
        }
        Rectangle {
            x: parent.width * Math.min(1, Math.max(0, s.shown)) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 7
            color: Theme.text
        }
    }
    MouseArea {
        cursorShape: Qt.PointingHandCursor
        id: area
        anchors.fill: parent
        function setV(mx) { s.dragValue = Math.max(0, Math.min(1, mx / track.width)); s.moved(s.dragValue) }
        onPressed: mouse => setV(mouse.x)
        onPositionChanged: mouse => { if (pressed) setV(mouse.x) }
        onReleased: s.dragValue = -1
    }
}
