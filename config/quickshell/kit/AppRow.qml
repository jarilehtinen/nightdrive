import QtQuick

// A list row's ground, for a ListView's delegate: the selected row's colour, or the fainter hover colour for the keyboard's
// place while the list isn't focused (marked) and under the pointer. It fills the list's width; what it shows goes inside.
Rectangle {
    id: root
    required property QtObject c
    property bool selected: false
    property bool marked: false
    readonly property alias hovered: hover.hovered
    width: ListView.view ? ListView.view.width : implicitWidth
    radius: 8
    color: selected ? c.sel : marked || hovered ? c.hover : "transparent"
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
}
