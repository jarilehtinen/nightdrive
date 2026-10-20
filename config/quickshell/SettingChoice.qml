import QtQuick

// One of a few choices side by side (a segmented control): title, an optional explanation, `options` (the labels) and
// `current` (an index); picked(i). (plugins/README.md › Settings windows)
Column {
    id: ch
    property string title: ""
    property string desc: ""
    property var options: []
    property int current: 0
    signal picked(int v)
    topPadding: 8; bottomPadding: 8
    spacing: 10
    Column {
        width: parent.width
        spacing: 4
        Text { width: parent.width; text: ch.title; color: Theme.text; font { family: Theme.font; pixelSize: 14 } }
        Text {
            visible: ch.desc !== ""
            width: parent.width
            text: ch.desc
            wrapMode: Text.Wrap
            lineHeight: 1.15
            color: Theme.dim
            font { family: Theme.font; pixelSize: 12 }
        }
    }
    Rectangle {
        width: parent.width; height: 36; radius: 8
        color: Qt.rgba(1, 1, 1, 0.05)
        Row {
            id: opts
            anchors { fill: parent; margins: 3 }
            spacing: 4
            Repeater {
                model: ch.options
                Rectangle {
                    required property string modelData
                    required property int index
                    readonly property bool on: ch.current === index
                    width: (opts.width - opts.spacing * (ch.options.length - 1)) / Math.max(1, ch.options.length); height: parent.height; radius: 6
                    // the theme colour, stronger than a selected row: the choice has to read at a glance
                    color: on ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.32) : area.containsMouse ? Theme.hover : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: parent.on ? Qt.lighter(Theme.accent, 1.08) : Theme.dim
                        font { family: Theme.font; pixelSize: 12; weight: parent.on ? Font.Medium : Font.Normal }
                    }
                    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.picked(parent.index) }
                }
            }
        }
    }
}
