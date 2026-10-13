import QtQuick

// A small section title inside a menu (e.g. "MACHINES"): small caps in the theme colour, smaller than the menu's own header.
Text {
    property string title: ""
    width: parent ? parent.width : 0
    topPadding: 6
    text: title.toUpperCase()
    color: Theme.primary
    font { family: Theme.font; pixelSize: 10; weight: Font.Medium; letterSpacing: 0.8 }
}
