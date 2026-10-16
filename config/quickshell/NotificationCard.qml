import QtQuick
import Quickshell
import Quickshell.Widgets

// One notification as a card: the app's icon and name with the time (× while the mouse is over it), the title, the text,
// the notification's own picture on the right (a preview, e.g. a screenshot: small under the text), and the app's
// actions as buttons. The popups (NotificationPopups.qml) and the notification menu (NotificationsMenu.qml) both draw
// these, so a notification looks the same in both.
// row = a history row from Notifs.qml; n = the live Notification while it's shown as a popup (its actions, updates), else null.
Rectangle {
    id: card

    // --- Tunables ---
    readonly property int iconSize: 18         // the app's icon
    readonly property int imageSize: 40        // the notification's own picture
    readonly property int previewHeight: 220   // at most: a preview picture under the text (row.preview: screenshots)

    property var row: ({})
    property var n: null
    readonly property var actions: n ? n.actions.filter(a => a.identifier !== "default") : []
    readonly property bool hovered: hover.hovered || shotDrag.active   // a drag of the preview keeps a popup up too
    signal activated()                         // click: open
    signal dismissed()                         // ×, right click or a two-finger swipe to the right

    // The popups slide the card in with these (NotificationPopups.qml); the swipe adds its own offset and fade
    property real enterX: 0
    property real appear: 1
    property real swipeX: 0
    readonly property real swipeFade: Math.max(0, Math.min(1, swipeX / width))

    width: 300
    height: body.implicitHeight + 28
    radius: 4                                  // the same as the windows' corners (decoration.rounding in hyprland.lua)
    opacity: appear * (1 - swipeFade)
    transform: Translate { x: card.enterX + card.swipeX }

    // Clear in the notification menu (sweep()): the card slides a little to the right and fades out. swept() when gone.
    signal swept()
    function sweep(delay) {
        sweeper.delay = delay
        sweeper.start()
    }
    SequentialAnimation {
        id: sweeper

        // --- Tunables ---
        readonly property int duration: 220    // ms
        readonly property real distance: 40    // px

        property int delay: 0
        PauseAnimation { duration: sweeper.delay }
        ParallelAnimation {
            NumberAnimation { target: card; property: "swipeX"; to: sweeper.distance; duration: sweeper.duration; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "appear"; to: 0; duration: sweeper.duration; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: card.swept() }
    }

    HoverHandler { id: hover }

    // Two-finger swipe to the right dismisses: the card follows the fingers and goes as soon as it's past swipeDistance
    // of its width, carrying on at the swipe's speed. A fast swipe that lifts earlier goes too, else it springs back.
    // Left doesn't move it.
    // Vertical scrolling isn't taken (orientation), so the notification menu's list still scrolls over the cards.
    WheelHandler {
        id: swipe

        // --- Tunables ---
        property real touchScale: 0.8          // the same as TouchScroll.qml
        property real swipeDistance: 0.17      // of the card's width
        property real flickSpeed: 900          // px/s to the right on release
        property real direction: -1            // natural_scroll = false: fingers to the right give a negative delta
        property real minOutSpeed: 400         // px/s: the slowest start when it goes
        property real outAccel: 6000           // px/s²: then it speeds up

        property var samples: []               // [time ms, dx] of the last 100 ms
        property double lastT: 0
        target: null
        acceptedDevices: PointerDevice.TouchPad
        orientation: Qt.Horizontal

        // The swipe's speed (px/s) at its last event; fingers that stopped before lifting give 0
        function speedNow() {
            if (samples.length === 0 || Date.now() - lastT > 60) return 0
            const span = Math.max(lastT - samples[0][0], 16)
            return samples.reduce((a, s) => a + s[1], 0) / span * 1000
        }
        function release() {
            const v = speedNow()
            samples = []
            if (v > flickSpeed && card.swipeX > 0) leave(v)
            else back.start()
        }
        function leave(v) {
            idle.stop()
            samples = []
            out.speed = Math.max(v, minOutSpeed)
            out.start()
        }

        onWheel: e => {
            if (out.running) return
            if (e.phase === Qt.ScrollEnd) { idle.stop(); release(); return }
            const raw = e.pixelDelta.x !== 0 ? e.pixelDelta.x * touchScale : e.angleDelta.x / 120 * 52
            const dx = raw * direction
            if (dx === 0) return
            back.stop()
            card.swipeX = Math.max(0, card.swipeX + dx)
            const now = Date.now()
            samples = samples.filter(s => now - s[0] <= 100).concat([[now, dx]])
            lastT = now
            if (card.swipeX > card.width * swipeDistance) { leave(speedNow()); return }
            idle.restart()                     // in case no ScrollEnd arrives: a pause counts as a release
        }
    }
    Timer { id: idle; interval: 100; onTriggered: swipe.release() }
    // Leaves at the swipe's own speed, so the card doesn't hitch when the fingers lift
    FrameAnimation {
        id: out
        property real speed: 0
        onTriggered: {
            const dt = Math.min(frameTime, 0.05)
            speed += swipe.outAccel * dt
            card.swipeX += speed * dt
            if (card.swipeX >= card.width + 20) { stop(); card.dismissed() }
        }
    }
    NumberAnimation { id: back; target: card; property: "swipeX"; to: 0; duration: 220; easing.type: Easing.OutBack }
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
            AppIcon {
                id: appIcon
                width: card.iconSize; height: card.iconSize
                anchors.verticalCenter: parent.verticalCenter
                readonly property string glyph: (card.row.icon || "").startsWith("lucide:") ? card.row.icon.slice(7) : ""
                name: glyph ? "" : card.row.icon || ""
                sourceSize: Qt.size(card.iconSize * 2, card.iconSize * 2)
                visible: status === Image.Ready
            }
            Text {      // a Lucide glyph as the icon (app_icon lucide:<name>, e.g. screenshots), or no icon anywhere: a bell
                anchors.centerIn: appIcon
                visible: !appIcon.visible
                text: Icons.g(appIcon.glyph || "bell")
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
                visible: !card.row.preview && picImg.status === Image.Ready
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

        // A preview picture (a screenshot) under the text, as wide as the card; a tall one at most previewHeight high and
        // narrower then (the whole picture always shows)
        Item { width: 1; height: shot.visible ? 10 : 0 }
        Item {
            id: shot
            readonly property real ar: shotImg.implicitWidth > 0 ? shotImg.implicitHeight / shotImg.implicitWidth : 0
            visible: !!card.row.preview && shotImg.status === Image.Ready && ar > 0
            width: parent.width
            height: visible ? Math.min(card.previewHeight, width * ar) : 0
            // Draggable as a file (text/uri-list): dropped on a terminal it's the file's path (Claude Code attaches
            // it as a picture), on a file manager or a browser the file. A click still opens the notification.
            readonly property string uri: {
                const i = card.row.image || ""
                return i.startsWith("/") ? "file://" + i : i.startsWith("file://") ? i : ""
            }
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": uri, "text/plain": decodeURIComponent(uri.slice(7)) })
            Drag.active: shotDrag.active
            DragHandler { id: shotDrag; target: null; enabled: shot.uri !== "" }
            // The picture under the pointer while dragging: a small copy of the preview
            function grabIcon() {
                if (shotImg.status !== Image.Ready || shotClip.width <= 0) return
                const sc = Math.min(1, 160 / shotClip.width)
                shotClip.grabToImage(r => shot.Drag.imageSource = r.url, Qt.size(shotClip.width * sc, shotClip.height * sc))
            }
            onHeightChanged: grabIcon()
            ClippingRectangle {
                id: shotClip
                width: Math.min(parent.width, parent.height / Math.max(shot.ar, 0.001)); height: parent.height
                radius: 6
                color: "transparent"
                border { width: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                Image {
                    id: shotImg
                    anchors.fill: parent
                    source: card.row.preview ? card.row.image : ""
                    sourceSize.width: 600
                    asynchronous: true
                    onStatusChanged: shot.grabIcon()
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
                        // invoke() itself closes a notification that isn't resident, and its popup and this card go with it
                        // at once: nothing here may be read after it
                        onClicked: btn.modelData.invoke()
                    }
                }
            }
        }
    }
}
