import QtQuick

// Menu row: icon, label, dimmed detail text and a trailing icon on the right edge.
Rectangle {
    id: row
    property string icon: ""
    property string label: ""
    property string detail: ""
    property string checkIcon: ""
    property bool active: false
    property bool danger: false
    property bool navSelected: false   // selected during keyboard navigation (⌘⇧Space)
    function navActivate() { row.clicked() }
    property bool action: false        // action button (Open …): uppercase, smaller font
    property bool busy: false          // in progress (connecting …): animated dots instead of the detail text
    signal clicked()
    signal rightClicked()

    height: 34
    radius: 5
    color: area.containsMouse || navSelected ? Theme.hover : (active ? Theme.sel : "transparent")
    border { width: navSelected ? 1 : 0; color: Theme.primary }

    readonly property color fg: danger ? Theme.danger : (active ? Theme.accent : Theme.text)

    Text {
        id: ic
        visible: row.icon !== ""
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        width: 20
        horizontalAlignment: Text.AlignHCenter
        text: Icons.g(row.icon)
        color: row.active || row.danger ? row.fg : Theme.dim
        font { family: Icons.family; pixelSize: 16 }
    }
    Text {
        anchors {
            left: ic.visible ? ic.right : parent.left; leftMargin: ic.visible ? 10 : 12
            right: trailing.left; rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        elide: Text.ElideRight
        text: row.action ? row.label.toUpperCase() : row.label
        color: row.fg
        font { family: Theme.font; pixelSize: row.action ? 11 : 13; letterSpacing: row.action ? 0.6 : 0 }
    }
    Row {
        id: trailing
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 8
        BusyDots {
            visible: row.busy
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: row.detail !== "" && !row.busy
            anchors.verticalCenter: parent.verticalCenter
            text: row.detail
            color: Theme.dim
            font { family: Theme.font; pixelSize: 11 }
        }
        Text {
            visible: row.checkIcon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.g(row.checkIcon)
            color: row.active ? Theme.accent : Theme.dim
            font { family: Icons.family; pixelSize: 16 }
        }
    }
    MouseArea {
        cursorShape: Qt.PointingHandCursor
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton ? row.rightClicked() : row.clicked()
    }
}
