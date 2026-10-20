import QtQuick
import Quickshell

// A drop-down list: the field shows `text` (rich text; empty: the current option's name), a click opens the options
// under it, joined to the field in the same grey, and a click on one gives picked(value). `model`: [{ value, name,
// swatch }] (swatch optional: a coloured dot), `current`: the value in use (a check mark). The list is a popup of its
// own, so it lies over whatever is below and a click anywhere else closes it. (plugins/README.md › Settings windows)
Rectangle {
    id: dd
    property var model: []
    property var current: undefined
    property string text: ""
    readonly property bool open: popup.visible
    signal picked(var value)
    function close() { popup.visible = false }

    height: 30; radius: 6
    bottomLeftRadius: open ? 0 : 6; bottomRightRadius: open ? 0 : 6     // open: joined to the list
    color: Qt.rgba(1, 1, 1, area.containsMouse || open ? 0.10 : 0.05)
    Text {
        anchors { left: parent.left; leftMargin: 10; right: chev.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
        elide: Text.ElideRight
        textFormat: Text.StyledText
        text: dd.text !== "" ? dd.text : ((dd.model.find(o => o.value === dd.current) || {}).name || "")
        color: Theme.text
        font { family: Theme.font; pixelSize: 13 }
    }
    Text {
        id: chev
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: Icons.g(dd.open ? "chevron-up" : "chevron-down")
        color: Theme.dim
        font { family: Icons.family; pixelSize: 14 }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: popup.visible = !popup.visible }

    PopupWindow {
        id: popup
        anchor.item: dd
        anchor.rect.y: dd.height
        implicitWidth: dd.width
        implicitHeight: list.implicitHeight + 8
        grabFocus: true          // a click outside closes it
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            radius: 6; topLeftRadius: 0; topRightRadius: 0
            // opaque: the field's 10 % white over the window, without what's below showing through
            color: Qt.tint(Qt.rgba(Theme.launcherBg.r, Theme.launcherBg.g, Theme.launcherBg.b, 1), Qt.rgba(1, 1, 1, 0.10))
            Column {
                id: list
                x: 4; y: 2
                width: parent.width - 8
                Repeater {
                    model: dd.model
                    Rectangle {
                        required property var modelData
                        readonly property bool on: modelData.value === dd.current
                        width: parent.width; height: 32; radius: 6
                        color: rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                        Rectangle {
                            id: dot
                            visible: parent.modelData.swatch !== undefined
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14; radius: 7
                            color: parent.modelData.swatch || "transparent"
                        }
                        Text {
                            anchors { left: dot.visible ? dot.right : parent.left; leftMargin: dot.visible ? 12 : 10
                                      right: mark.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                            text: parent.modelData.name
                            color: parent.on ? Theme.accent : Theme.text
                            font { family: Theme.font; pixelSize: 13 }
                        }
                        Text {
                            id: mark
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: parent.on ? Icons.g("check") : ""
                            color: Theme.accent
                            font { family: Icons.family; pixelSize: 14 }
                        }
                        MouseArea {
                            id: rowArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { popup.visible = false; dd.picked(parent.modelData.value) }
                        }
                    }
                }
            }
        }
    }
}
