import QtQuick

// Separator line in menus. pad = extra margin above and below the line (the Column's spacing is added on top).
Item {
    id: d
    property int pad: 11
    width: parent ? parent.width : 0
    height: 1 + 2 * pad
    Rectangle { y: d.pad; width: parent.width; height: 1; color: Theme.border }
}
