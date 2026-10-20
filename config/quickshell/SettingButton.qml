import QtQuick

// A button in a settings window: `text`, `strong` for the main action (the theme colour), `active: false` dims it and
// it does nothing; clicked(). (plugins/README.md › Settings windows)
Rectangle {
    id: bt
    property string text: ""
    property bool active: true
    property bool strong: false
    signal clicked()
    width: btText.implicitWidth + 24; height: 30; radius: 6
    color: !active ? Qt.rgba(1, 1, 1, 0.03)
         : strong ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, btArea.containsMouse ? 0.45 : 0.32)
         : Qt.rgba(1, 1, 1, btArea.containsMouse ? 0.10 : 0.05)
    Text {
        id: btText
        anchors.centerIn: parent
        text: bt.text
        color: !bt.active ? Qt.rgba(Theme.dim.r, Theme.dim.g, Theme.dim.b, 0.5) : bt.strong ? Qt.lighter(Theme.accent, 1.08) : Theme.text
        font { family: Theme.font; pixelSize: 12; weight: bt.strong ? Font.Medium : Font.Normal }
    }
    MouseArea {
        id: btArea; anchors.fill: parent; hoverEnabled: true
        cursorShape: bt.active ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (bt.active) bt.clicked()
    }
}
