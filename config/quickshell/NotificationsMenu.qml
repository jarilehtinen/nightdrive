import QtQuick
import Quickshell

// Hamburger menu: notifications (Notifs.qml's history + do-not-disturb toggle), ⌘Esc / F3.
// A bare menu (shell.qml draws no card around it): a bar with the title and the controls, then each notification as its
// own card, the same as the popups (NotificationCard.qml) and in the same place, so one is easy to find again.
// Click = open the app, ×, right click or a two-finger swipe right = remove it, Clear = remove all (the cards slide
// a little to the right and fade out one after another, NotificationCard.sweep()).
// The power actions (lock, suspend, log out, reboot, shut down) live in the launcher (⌘Space › Power).
Column {
    id: m

    // --- Tunables ---
    readonly property int maxCards: 6          // shown whole, then the list scrolls (no sliver of the next one)
    readonly property real bgOpacity: 0.85     // the same as the popups (NotificationPopups.qml)

    readonly property bool bare: true
    readonly property int preferredWidth: 300   // the popups' width
    width: parent ? parent.width : 300
    spacing: 10                                 // the popups' gap

    property real lastShownBottom: -1           // the bottom of card number maxCards (set by that card)

    // Clear: the cards in view go one after another from the top, the history empties when the last is gone
    property bool clearing: false
    property int sweeping: 0
    function clearAll() {
        if (clearing) return
        clearing = true
        let n = 0
        for (let i = 0; i < rep.count; i++) {
            const c = rep.itemAt(i)
            if (!c || c.y + c.height <= flick.contentY || c.y >= flick.contentY + flick.height) continue
            c.sweep(n * 40)
            n++
        }
        sweeping = n
        if (n === 0) cleared()
    }
    function sweptOne() { if (--sweeping <= 0) cleared() }
    function cleared() { Notifs.history = []; clearing = false }

    Component.onDestruction: {
        Notifs.menuOpen = false
        if (clearing) Notifs.history = []      // the menu closed mid-clear
    }

    signal close()

    Component.onCompleted: { Notifs.now = Date.now(); Notifs.menuOpen = true }     // fresh "min ago" when the menu opens

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
            function navActivate() { m.clearAll() }
            readonly property bool on: Notifs.history.length > 0 && !m.clearing
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
        height: Notifs.history.length > m.maxCards && m.lastShownBottom > 0 ? m.lastShownBottom : cards.implicitHeight
        contentHeight: cards.implicitHeight
        clip: true
        interactive: !m.clearing
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick   // a sideways swipe is the card's (swipe to dismiss)
        TouchScroll { view: flick; step: 60 }
        Column {
            id: cards
            width: flick.width
            spacing: 10
            // The cards below a removed one slide up into its place
            move: Transition { NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic } }
            Repeater {
                id: rep
                // ScriptModel keeps the other cards when one goes (a plain array would make them all again)
                model: ScriptModel { values: Notifs.history }
                NotificationCard {
                    id: card
                    required property var modelData
                    required property int index
                    row: modelData
                    width: cards.width
                    enabled: !m.clearing
                    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, m.bgOpacity)
                    onSwept: m.sweptOne()
                    onActivated: { Notifs.openApp(modelData); m.close() }
                    onDismissed: Notifs.forget(modelData.uid)
                    Binding { when: card.index === m.maxCards - 1; target: m; property: "lastShownBottom"; value: card.y + card.height }
                }
            }
        }
    }
}
