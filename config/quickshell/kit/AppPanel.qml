import QtQuick

// A panel over the window (settings, a question before what can't be undone, a first start): the window dimmed behind a
// card in the middle, what it holds in a column inside. A click outside comes out as outsideTapped (most panels close on
// it); its keys are the app's (Keys.onPressed on the panel, once it has the focus).
Rectangle {
    id: root
    required property QtObject c
    property int cardWidth: 560
    property alias spacing: column.spacing
    default property alias content: column.data
    signal outsideTapped()
    anchors.fill: parent
    color: c.scrim
    TapHandler { onTapped: root.outsideTapped() }
    Rectangle {
        anchors.centerIn: parent
        width: root.cardWidth
        height: column.implicitHeight + 72
        radius: 14
        color: root.c.solid
        border.color: root.c.line
        TapHandler {}       // a click inside keeps it open
        Column {
            id: column
            x: 40; y: 36
            width: parent.width - 80
            spacing: 18
        }
    }
}
