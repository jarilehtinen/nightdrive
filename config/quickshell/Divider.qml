import QtQuick

// Separator line in menus. pad = extra margin above and below the line (the Column's spacing is added on top);
// padBottom sets the margin below separately.
Item {
    id: d
    property int pad: 11
    property int padBottom: pad
    width: parent ? parent.width : 0
    height: 1 + pad + padBottom
    Rectangle { y: d.pad; width: parent.width; height: 1; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) }   // a faint line of the theme colour
}
