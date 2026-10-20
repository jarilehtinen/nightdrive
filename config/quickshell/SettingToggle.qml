import QtQuick

// A setting that is on or off: its title, an optional explanation under it, and a switch on the right.
// picked(v) with the new value; the owner sets `checked` (as it applies the change).
// (Settings windows: AirPodsSettings, ThemeEditor; plugins/README.md › Settings windows.)
Item {
    id: tg
    property string title: ""
    property string desc: ""
    property bool checked: false
    signal picked(bool v)
    height: Math.max(t.implicitHeight, 20) + 16
    Column {
        id: t
        y: 8
        width: parent.width - 50
        spacing: 4
        Text { width: parent.width; text: tg.title; color: Theme.text; font { family: Theme.font; pixelSize: 14 } }
        Text {
            visible: tg.desc !== ""
            width: parent.width
            text: tg.desc
            wrapMode: Text.Wrap
            lineHeight: 1.15
            color: Theme.dim
            font { family: Theme.font; pixelSize: 12 }
        }
    }
    Rectangle {
        anchors.right: parent.right; y: 10
        width: 34; height: 20; radius: 10
        color: tg.checked ? Theme.accent : Theme.border
        Rectangle {
            width: 14; height: 14; radius: 7; y: 3
            x: tg.checked ? 17 : 3
            color: tg.checked ? Theme.bg : Theme.text
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        MouseArea { cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: tg.picked(!tg.checked) }
    }
}
