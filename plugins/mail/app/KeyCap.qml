import QtQuick

// Keys in rounded boxes, as the desktop's Claude writes card shows them: "⌘N  c" (alternatives two spaces apart) is a box
// for each. A hint puts these first and its text after them.
Row {
    id: root
    required property QtObject c
    property string keys: ""
    property color tint: c.dim
    spacing: 4
    Repeater {
        model: root.keys.split("  ").filter(k => k !== "")
        delegate: Rectangle {
            required property string modelData
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(22, cap.implicitWidth + 14); height: 22; radius: 6
            color: "transparent"
            border { width: 1; color: root.tint }
            Text {
                id: cap
                anchors.centerIn: parent
                text: parent.modelData
                color: root.tint
                font { family: root.c.font; pixelSize: parent.modelData.length === 1 ? 13 : 11 }
            }
        }
    }
}
