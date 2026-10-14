import QtQuick
import Quickshell

// Hamburger menu: notifications (Notifs.qml's history + do-not-disturb toggle), ⌘Esc / F3.
// A bare menu (shell.qml draws no card around it): a bar with the title and the controls, then each notification as its
// own card, the same as the popups (NotificationCard.qml) and in the same place, so one is easy to find again.
// Click = open the app, × or right click = remove it, Clear = remove all.
// The power actions (lock, suspend, log out, reboot, shut down) live in the launcher (⌘Space › Power).
Column {
    id: m

    // --- Tunables ---
    readonly property int maxListHeight: 620   // then the list scrolls
    readonly property real bgOpacity: 0.85     // the same as the popups (NotificationPopups.qml)

    readonly property bool bare: true
    readonly property int preferredWidth: 300   // the popups' width
    width: parent ? parent.width : 300
    spacing: 10                                 // the popups' gap

    signal close()

    Component.onCompleted: Notifs.now = Date.now()     // fresh "min ago" when the menu opens

    // Toggle on = notifications are shown; off = do not disturb (hypr/scripts/dnd: also shows the OSD). Clear next to it.
    Rectangle {
        width: parent.width
        height: 46
        radius: 4
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, m.bgOpacity)
        MenuHeader {
            id: header
            anchors { left: parent.left; right: parent.right; leftMargin: 17; rightMargin: 17; verticalCenter: parent.verticalCenter }
            title: "Notifications"
            showToggle: true; checked: !Notifs.dnd
            onToggled: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/dnd"])
        }
        Rectangle {
            id: clear
            // keyboard navigation (shell.qml: ⌘⇧Space, arrows): a row the menu can select
            property bool navSelected: false
            readonly property bool navEnabled: Notifs.history.length > 0
            function navActivate() { Notifs.history = [] }
            readonly property bool on: Notifs.history.length > 0
            readonly property bool lit: on && (clearArea.containsMouse || navSelected)
            anchors { right: parent.right; rightMargin: 61; verticalCenter: parent.verticalCenter }   // left of the toggle (17 + 34 + 10)
            width: clearText.implicitWidth + 18; height: 20; radius: 10
            color: lit ? Theme.sel : "transparent"
            border.width: 1
            border.color: lit ? Theme.primary : Theme.border
            opacity: on ? 1 : 0.4
            Text {
                id: clearText
                anchors.centerIn: parent
                text: "CLEAR"
                color: clear.lit ? Theme.accent : Theme.dim
                font { family: Theme.font; pixelSize: 9; letterSpacing: 0.8 }
            }
            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: clear.on
                cursorShape: Qt.PointingHandCursor
                onClicked: clear.navActivate()
            }
        }
    }

    Flickable {
        id: flick
        visible: Notifs.history.length > 0
        width: parent.width
        height: Math.min(cards.implicitHeight, m.maxListHeight)
        contentHeight: cards.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        TouchScroll { view: flick; step: 60 }
        Column {
            id: cards
            width: flick.width
            spacing: 10
            Repeater {
                model: Notifs.history
                NotificationCard {
                    required property var modelData
                    row: modelData
                    width: cards.width
                    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, m.bgOpacity)
                    onActivated: { Notifs.openApp(modelData); m.close() }
                    onDismissed: Notifs.forget(modelData.uid)
                }
            }
        }
    }
    Rectangle {
        visible: Notifs.history.length === 0
        width: parent.width; height: 46
        radius: 4
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, m.bgOpacity)
        Text {
            anchors { left: parent.left; leftMargin: 17; verticalCenter: parent.verticalCenter }
            text: "No notifications"; color: Theme.dim
            font { family: Theme.font; pixelSize: 12 }
        }
    }
}
