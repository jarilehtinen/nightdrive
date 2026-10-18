import QtQuick

// A section title inside a menu (e.g. "MACHINES"): capitals in the theme colour, smaller than the menu's own header.
// An optional subtitle on the right, dimmed as in MenuHeader (e.g. what the numbers below it mean).
Text {
    id: s
    property string title: ""
    property string subtitle: ""
    width: parent ? parent.width : 0
    topPadding: 6
    text: title.toUpperCase()
    color: Theme.primary
    font { family: Theme.font; pixelSize: 11; letterSpacing: 0.6 }
    Text {
        visible: s.subtitle !== ""
        anchors { right: parent.right; baseline: parent.baseline }
        text: s.subtitle.toUpperCase()
        color: Theme.dim
        font { family: Theme.font; pixelSize: 10; letterSpacing: 0.6 }
    }
}
