import QtQuick

// A battery drawn as one: a rounded body filled to the level, the terminal on its right. Not a slider's track, so a
// charge never looks like something to drag. Battery menu: a large one; Headphones menu (BatteryBar): a low one per bar.
//   level 0..100, color (the fill), bolt: a bolt in the middle (charging)
// The corners, inset and terminal follow the height.
Item {
    id: s
    property int level: 0
    property color color: Theme.primary
    property bool bolt: false
    property real fillOpacity: 1

    readonly property real inset: Math.max(2, Math.round(height / 9))
    implicitHeight: 34

    Rectangle {      // the body
        id: body
        width: parent.width - nub.width - 2
        height: parent.height
        radius: Math.round(height * 0.24)
        color: "transparent"
        border { width: height >= 24 ? 1.5 : 1; color: Theme.dim }
        Rectangle {  // the charge
            x: s.inset; y: s.inset
            width: Math.max(0, (parent.width - 2 * s.inset) * Math.max(0, Math.min(100, s.level)) / 100)
            height: parent.height - 2 * s.inset
            radius: Math.max(1, body.radius - s.inset)
            color: s.color
            opacity: s.fillOpacity
        }
        Text {
            visible: s.bolt
            anchors.centerIn: parent
            text: Icons.g("zap")
            color: Theme.bg
            style: Text.Outline; styleColor: s.color
            font { family: Icons.family; pixelSize: Math.round(s.height * 0.53) }
        }
    }
    Rectangle {      // the terminal
        id: nub
        anchors { left: body.right; leftMargin: 2; verticalCenter: body.verticalCenter }
        width: s.height >= 24 ? 4 : 3
        height: Math.round(s.height * 0.36)
        radius: width / 2
        color: Theme.dim
    }
}
