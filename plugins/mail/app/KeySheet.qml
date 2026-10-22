import QtQuick

// The keys of a window, shown while ⌘ (Super) is held, or after ?, until any key. The window passes its key events to
// pressed() and released(); any other key in between cancels the hold, so ⌘ shortcuts stay quiet.
Rectangle {
    id: root
    required property QtObject c
    property var groups: []             // [{ title, keys: [[key, what], …] }, …]
    property int columns: 2
    property bool shown: false
    readonly property int hold: 500     // ms ⌘ is held before the keys show

    function isSuper(k) { return k === Qt.Key_Super_L || k === Qt.Key_Super_R || k === Qt.Key_Meta }
    function pressed(e) {
        if (isSuper(e.key)) { if (!e.isAutoRepeat) timer.restart() }
        else { timer.stop(); if (e.key !== Qt.Key_Question) shown = false }
    }
    function released(e) { if (isSuper(e.key)) { timer.stop(); shown = false } }
    Timer { id: timer; interval: root.hold; onTriggered: root.shown = true }

    anchors.fill: parent
    visible: shown
    color: root.c.scrim
    Rectangle {
        anchors.centerIn: parent
        width: grid.implicitWidth + 80
        height: grid.implicitHeight + 72
        radius: 14
        color: root.c.solid
        border.color: root.c.line
        Grid {
            id: grid
            anchors.centerIn: parent
            columns: root.columns
            columnSpacing: 56
            rowSpacing: 32
            Repeater {
                model: root.groups
                delegate: Column {
                    required property var modelData
                    spacing: 10
                    Text { text: modelData.title; color: root.c.title; font.family: root.c.font; font.pixelSize: 13; font.weight: Font.Medium; bottomPadding: 4 }
                    Repeater {
                        model: modelData.keys
                        delegate: Row {
                            required property var modelData
                            spacing: 12
                            Item {
                                width: 150; height: 22
                                KeyCap { anchors.verticalCenter: parent.verticalCenter; c: root.c; keys: modelData[0]; tint: root.c.accent }
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; color: root.c.dim; font.family: root.c.font; font.pixelSize: 12 }
                        }
                    }
                }
            }
        }
    }
}
