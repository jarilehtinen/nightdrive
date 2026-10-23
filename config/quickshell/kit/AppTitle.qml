import QtQuick

// The app's name at the top of its sidebar, with the block cursor of Nightdrive's wordmark after it: "Mail█".
Row {
    id: root
    required property QtObject c
    property string text
    height: 22
    spacing: 3
    Text { anchors.verticalCenter: parent.verticalCenter; text: root.text; color: root.c.title; font.family: root.c.font; font.pixelSize: 13; font.weight: Font.DemiBold }
    Rectangle { width: 7; height: 14; color: root.c.primary; anchors.verticalCenter: parent.verticalCenter }
}
