import QtQuick
import Quickshell
import Quickshell.Widgets

// One notification as a card: the app's icon and name with the time (× while the mouse is over it), the title, the text,
// the notification's own picture on the right, and the app's actions as buttons. The popups (NotificationPopups.qml) and
// the notification menu (NotificationsMenu.qml) both draw these, so a notification looks the same in both.
// row = a history row from Notifs.qml; n = the live Notification while it's shown as a popup (its actions, updates), else null.
Rectangle {
    id: card

    // --- Tunables ---
    readonly property int iconSize: 18         // the app's icon
    readonly property int imageSize: 40        // the notification's own picture

    property var row: ({})
    property var n: null
    readonly property var actions: n ? n.actions.filter(a => a.identifier !== "default") : []
    readonly property bool hovered: hover.hovered
    signal activated()                         // click: open
    signal dismissed()                         // × or right click

    width: 300
    height: body.implicitHeight + 28
    radius: 4                                  // the same as the windows' corners (decoration.rounding in hyprland.lua)

    HoverHandler { id: hover }
    MouseArea {
        id: area
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.RightButton ? card.dismissed() : card.activated()
    }

    Column {
        id: body
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 14; leftMargin: 17; rightMargin: 17 }
        spacing: 0

        // App: icon, name, time (× while the mouse is over the card)
        Item {
            width: parent.width
            height: card.iconSize
            Image {
                id: appIcon
                width: card.iconSize; height: card.iconSize
                anchors.verticalCenter: parent.verticalCenter
                source: card.row.icon || ""
                sourceSize: Qt.size(card.iconSize * 2, card.iconSize * 2)
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }
            Text {      // no icon anywhere: a bell
                anchors.centerIn: appIcon
                visible: !appIcon.visible
                text: Icons.g("bell")
                color: Theme.dim
                font { family: Icons.family; pixelSize: card.iconSize - 4 }
            }
            Text {
                anchors { left: appIcon.right; leftMargin: 8; right: corner.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: (card.row.app || "Notification").toUpperCase()
                color: Theme.dim
                font { family: Theme.font; pixelSize: 10; letterSpacing: 1 }
            }
            Text {
                id: corner
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: card.hovered ? Icons.g("x") : Notifs.ago(card.row.time)
                color: closeArea.containsMouse ? Theme.accent : Theme.dim
                font { family: card.hovered ? Icons.family : Theme.font
                       pixelSize: card.hovered ? 14 : 10 }
                MouseArea {
                    id: closeArea
                    anchors { fill: parent; margins: -8 }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.dismissed()
                }
            }
        }

        Item { width: 1; height: 8 }

        // Title and text, the notification's picture on the right
        Item {
            width: parent.width
            height: Math.max(texts.implicitHeight, pic.visible ? card.imageSize : 0)
            Column {
                id: texts
                anchors { left: parent.left; right: pic.visible ? pic.left : parent.right; rightMargin: pic.visible ? 12 : 0 }
                spacing: 3
                Text {
                    width: parent.width
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: card.n ? card.n.summary : card.row.summary
                    color: Theme.primary
                    font { family: Theme.font; pointSize: 9.25; weight: Font.Bold }   // 1 px under mako's 10 pt
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: (card.n ? card.n.body : card.row.body).replace(/<[^>]*>/g, "")
                    color: Theme.muted
                    font { family: Theme.font; pointSize: 8.875 }   // ≈ 11.8 px
                }
            }
            ClippingRectangle {
                id: pic
                visible: picImg.status === Image.Ready
                anchors { right: parent.right; top: parent.top }
                width: card.imageSize; height: card.imageSize
                radius: 8
                color: "transparent"
                Image {
                    id: picImg
                    anchors.fill: parent
                    source: card.row.image || ""
                    sourceSize: Qt.size(card.imageSize * 2, card.imageSize * 2)
                    fillMode: Image.PreserveAspectCrop
                }
            }
        }

        // The app's other actions as buttons
        Item { width: 1; height: card.actions.length ? 10 : 0 }
        Row {
            visible: card.actions.length > 0
            spacing: 8
            Repeater {
                model: card.actions
                Rectangle {
                    id: btn
                    required property var modelData
                    width: btnText.implicitWidth + 20; height: 26
                    radius: 7
                    color: btnArea.containsMouse ? Theme.sel : Qt.rgba(1, 1, 1, 0.06)
                    Text {
                        id: btnText
                        anchors.centerIn: parent
                        text: btn.modelData.text
                        color: btnArea.containsMouse ? Theme.accent : Theme.text
                        font { family: Theme.font; pixelSize: 11 }
                    }
                    MouseArea {
                        id: btnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { btn.modelData.invoke(); if (card.n && !card.n.resident) card.dismissed() }
                    }
                }
            }
        }
    }
}
