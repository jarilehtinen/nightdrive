import QtQuick
import Quickshell
import Quickshell.Wayland

// Notification popups (top right, below the bar; data in Notifs.qml, the card in NotificationCard.qml). Click = open (the
// app's default action or its window), right click or × = dismiss, the mouse over a card keeps it. Hyprland blurs what's
// behind the cards (layer rule in hyprland.lua, namespace nightdrive-notifications).
PanelWindow {
    id: win

    // --- Tunables ---
    readonly property int cardWidth: 300
    readonly property int gap: 10              // between cards, and from the screen edge
    readonly property real bgOpacity: 0.85

    visible: Notifs.popups.length > 0
    anchors { top: true; right: true }
    margins { top: gap; right: gap }
    implicitWidth: cardWidth
    implicitHeight: Math.max(1, cards.implicitHeight)
    color: "transparent"
    exclusionMode: ExclusionMode.Normal        // below the bar, like mako was
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nightdrive-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Column {
        id: cards
        width: win.cardWidth
        spacing: win.gap
        Repeater {
            model: Notifs.popups
            NotificationCard {
                id: card
                required property var modelData
                n: modelData.n
                row: modelData.entry
                width: win.cardWidth
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, win.bgOpacity)
                onActivated: Notifs.activate(modelData)
                onDismissed: if (n) n.dismiss()

                // Slides in from the right
                opacity: 0
                transform: Translate { id: slide; x: 40 }
                Component.onCompleted: enter.start()
                ParallelAnimation {
                    id: enter
                    NumberAnimation { target: card; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
                    NumberAnimation { target: slide; property: "x"; to: 0; duration: 200; easing.type: Easing.OutCubic }
                }

                // Goes after Notifs.timeout; the mouse over the card restarts the wait, critical ones stay
                Timer {
                    running: !card.row.critical && !card.hovered
                    interval: Notifs.timeout
                    onTriggered: if (card.n) card.n.expire()
                }
            }
        }
    }
}
