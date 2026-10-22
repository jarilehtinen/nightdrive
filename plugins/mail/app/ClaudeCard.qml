import QtQuick
import qs

// Claude's reply, shown first in a card by the mouse, as the desktop's own ⌘⇧C shows it (Nightdrive's ClaudeWrite.qml):
// what was sent, then the text. Enter puts it in place, ⌘⇧C writes another version, Esc or a click outside cancels.
// It covers the writing window so nothing is typed under it while Claude writes.
Item {
    id: root
    required property QtObject c
    property real px: 0                 // where it opens: the mouse, or the caret (in this item's coordinates)
    property real py: 0
    property string sent: ""            // what went to Claude, in a line
    property string phase: ""           // working | done | error
    property string result: ""
    property string error: ""
    property string acceptText: "Insert"

    signal accepted()
    signal again()
    signal cancelled()

    function open(x, y) { px = x; py = y; phase = "working"; result = ""; error = ""; visible = true; keys.forceActiveFocus() }
    function done(text) { result = text; phase = "done" }
    function fail(text) { error = text; phase = "error" }
    function close() { visible = false }

    visible: false
    anchors.fill: parent

    MouseArea { anchors.fill: parent; onClicked: root.cancelled() }

    Item {
        id: keys
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) root.cancelled()
            else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && root.phase === "done") root.accepted()
            else return
            e.accepted = true
        }
    }

    readonly property var hints: phase === "done" ? [{ keys: ["⏎"], text: acceptText }, { keys: ["⌘", "⇧", "C"], text: "Write new" }, { keys: ["esc"], text: "Cancel" }]
        : phase === "error" ? [{ keys: ["⌘", "⇧", "C"], text: "Try again" }, { keys: ["esc"], text: "Close" }]
        : [{ keys: ["esc"], text: "Cancel" }]

    // Below the point, kept inside the window
    Rectangle {
        id: card
        width: Math.min(480, root.width - 32)
        height: body.implicitHeight + 32
        x: Math.max(16, Math.min(root.px - 24, root.width - width - 16))
        y: root.py + 24 + height < root.height - 16 ? root.py + 24 : Math.max(16, root.py - 24 - height)
        radius: 12
        color: root.c.solid
        border { color: root.c.primary; width: 2 }
        MouseArea { anchors.fill: parent }

        Column {
            id: body
            x: 16; y: 16
            width: parent.width - 32
            spacing: 10

            Row {
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.g("sparkles")
                    color: root.c.accent
                    font { family: Icons.family; pixelSize: 16 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Claude writes"
                    color: root.c.title
                    font { family: root.c.font; pixelSize: 14; bold: true }
                }
            }

            // What was sent, so it's clear what left the machine
            Text {
                width: parent.width
                text: "Sent: " + root.sent.replace(/\s+/g, " ").trim()
                color: root.c.dim
                elide: Text.ElideRight
                font { family: root.c.font; pixelSize: 12 }
            }

            // Three dots taking turns while Claude writes
            Row {
                id: dots
                visible: root.phase === "working"
                property int turn: 0
                spacing: 5
                topPadding: 4; bottomPadding: 4
                Timer { running: dots.visible; interval: 280; repeat: true; onTriggered: dots.turn = (dots.turn + 1) % 3 }
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        width: 6; height: 6; radius: 3
                        color: root.c.primary
                        opacity: index === dots.turn ? 1 : 0.25
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }
            }
            Text {
                visible: root.phase === "error"
                width: parent.width
                wrapMode: Text.Wrap
                text: root.error
                color: root.c.danger
                font { family: root.c.font; pixelSize: 13 }
            }
            Rectangle {
                visible: root.phase === "done"
                width: parent.width
                height: Math.min(resultText.implicitHeight, 320) + 20
                radius: 8
                color: root.c.hover
                Flickable {
                    x: 10; y: 10
                    width: parent.width - 20; height: parent.height - 20
                    contentHeight: resultText.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    Text {
                        id: resultText
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: root.result
                        textFormat: Text.PlainText
                        color: root.c.text
                        font { family: root.c.font; pixelSize: 13 }
                    }
                }
            }

            // The keys, framed as the desktop's card frames them
            Flow {
                width: parent.width
                topPadding: 2
                spacing: 14
                Repeater {
                    model: root.hints
                    Row {
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: caps.implicitWidth + 14; height: 22; radius: 6
                            color: "transparent"
                            border { width: 1; color: root.c.dim }
                            Row {
                                id: caps
                                anchors.centerIn: parent
                                spacing: 4
                                Repeater {
                                    model: modelData.keys
                                    Text {
                                        required property string modelData
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData
                                        color: root.c.dim
                                        font { family: root.c.font; pixelSize: modelData.length === 1 ? 13 : 11 }
                                    }
                                }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            color: root.c.dim
                            font { family: root.c.font; pixelSize: 12 }
                        }
                    }
                }
            }
        }
    }
}
