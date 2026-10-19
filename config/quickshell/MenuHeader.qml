import QtQuick

// Title, an optional subtitle on the right (smaller, dimmed: e.g. the Claude plan), an optional on/off toggle on the right edge,
// and an optional small button left of it (`action: "Clear"`, `onActionClicked`), dimmed while `actionEnabled` is false.
Item {
    id: h
    property string title: ""
    property string subtitle: ""
    property bool showToggle: false
    property bool checked: false
    signal toggled()
    property string action: ""
    property bool actionEnabled: true
    signal actionClicked()
    property bool navSelected: false   // selected during keyboard navigation
    readonly property bool navEnabled: showToggle || (action !== "" && actionEnabled)
    function navActivate() { if (showToggle) toggled(); else if (action !== "" && actionEnabled) actionClicked() }

    height: 26
    Text {
        id: titleText
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: h.title.toUpperCase()
        color: Theme.primary
        font { family: Theme.font; pixelSize: 12; weight: Font.Medium; letterSpacing: 0.6 }
    }
    Text {
        visible: h.subtitle !== ""
        anchors { right: h.action !== "" ? actionPill.left : parent.right; rightMargin: h.action !== "" ? 10 : h.showToggle ? 44 : 0
                  baseline: titleText.baseline }
        text: h.subtitle.toUpperCase()
        color: Theme.dim
        font { family: Theme.font; pixelSize: 10; letterSpacing: 0.6 }
    }
    // The button: a pill like the notifications' Clear
    Rectangle {
        id: actionPill
        visible: h.action !== ""
        readonly property bool lit: h.actionEnabled && (actionArea.containsMouse || (h.navSelected && !h.showToggle))
        anchors { right: parent.right; rightMargin: h.showToggle ? 44 : 0; verticalCenter: parent.verticalCenter }
        width: actionText.implicitWidth + 18; height: 20; radius: 10
        color: lit ? Theme.sel : "transparent"
        border.width: 1
        border.color: lit ? Theme.primary : Theme.border
        opacity: h.actionEnabled ? 1 : 0.4
        Text {
            id: actionText
            anchors.centerIn: parent
            text: h.action.toUpperCase()
            color: actionPill.lit ? Theme.accent : Theme.dim
            font { family: Theme.font; pixelSize: 9; letterSpacing: 0.8 }
        }
        MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: h.actionEnabled
            cursorShape: Qt.PointingHandCursor
            onClicked: h.actionClicked()
        }
    }
    Rectangle {
        visible: h.showToggle
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 34; height: 20; radius: 10
        color: h.navSelected ? Theme.primary : (h.checked ? Theme.accent : Theme.border)   // keyboard focus: the whole toggle turns violet
        Rectangle {
            width: 14; height: 14; radius: 7; y: 3
            x: h.checked ? 17 : 3
            color: h.checked ? Theme.bg : Theme.text
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        MouseArea { cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: h.toggled() }
    }
}
