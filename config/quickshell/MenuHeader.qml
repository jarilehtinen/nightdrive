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
    // apart: a header further down a menu (Sound's Microphone, Headphones' Equalizer): a section title with a toggle. Its
    // title is a MenuSection's size, so only the menu's own header is large, and it gets some room above it in place of
    // a divider (less than MenuSection's apart: the rows above it already end in their own padding)
    property bool apart: false
    readonly property int lead: apart ? 8 : 0

    height: 26 + lead
    Text {
        id: titleText
        anchors { left: parent.left; verticalCenter: parent.verticalCenter; verticalCenterOffset: h.lead / 2 }
        text: h.title.toUpperCase()
        color: Theme.primary
        font { family: Theme.font; pixelSize: h.apart ? 11 : 12; weight: h.apart ? Font.Normal : Font.Medium; letterSpacing: 0.6 }
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
        anchors { right: parent.right; rightMargin: h.showToggle ? 44 : 0; verticalCenter: parent.verticalCenter; verticalCenterOffset: h.lead / 2 }
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
    Toggle {
        visible: h.showToggle
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: h.lead / 2 }
        checked: h.checked
        navSelected: h.navSelected
        onToggled: h.toggled()
    }
}
