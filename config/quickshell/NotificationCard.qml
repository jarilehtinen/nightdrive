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
    transform: [
        Rotation { origin.x: card.width / 2; origin.y: card.height / 2; angle: card.fallAngle },
        Translate { x: card.enterX + card.swipeX + card.fallX; y: card.fallY }
    ]

    // Clear in the notification menu (fall()): one screw gives, the card swings from the other like a sign (a real
    // pendulum, damped a little), then that one gives too and the card drops off the screen spinning. fell() when gone.
    property real fallAngle: 0                 // degrees, about the card's centre
    property real fallX: 0                     // the centre's move
    property real fallY: 0
    signal fell()
    // Moves the card to where it falls (the menu's window without blur) to the same place on the screen, before fall()
    function detachTo(where, x, y, bg) {
        parent = where
        card.x = x
        card.y = y
        color = bg
    }
    // side: 1 = hangs from the left screw, -1 = the right; hang: s before it drops
    function fall(delay, side, hang) {
        faller.side = side
        faller.hang = hang
        fallStart.interval = Math.max(1, delay)
        fallStart.start()
    }
    Timer { id: fallStart; onTriggered: faller.begin() }
    FrameAnimation {
        id: faller

        // --- Tunables ---
        readonly property real g: 4500         // px/s²
        readonly property real damping: 1.2    // 1/s
        readonly property real spinKeep: 1     // of the swing's turning speed kept while it falls

        property real side: 1
        property real hang: 0.5
        property real t: 0
        property real th: 0                    // angle (rad, clockwise)
        property real om: 0                    // its speed
        property real vx: 0
        property real vy: 0
        property bool free: false
        // While it falls the card is one texture that only moves (layer): its text isn't drawn again every frame
        function begin() {
            t = 0; th = 0; om = 0; free = false
            card.z = 1
            card.layer.enabled = true
            card.layer.smooth = true
            start()
        }

        onTriggered: {
            const dt = Math.min(frameTime, 0.033)
            const w = card.width, h = card.height
            const rx = side * w / 2, ry = h / 2           // the centre seen from the screw (top left or top right corner)
            t += dt
            if (!free) {
                // A rectangle swinging from its corner: θ'' = −3·g·r / (w² + h²) · sin(θ − θrest)
                const r = Math.hypot(rx, ry)
                om += (-3 * g * r / (w * w + h * h) * Math.sin(th - Math.atan2(rx, ry)) - damping * om) * dt
                th += om * dt
                const ox = rx * Math.cos(th) - ry * Math.sin(th), oy = rx * Math.sin(th) + ry * Math.cos(th)
                card.fallX = ox - rx
                card.fallY = oy - ry
                if (t >= hang) { free = true; vx = -om * oy; vy = om * ox; om *= spinKeep }   // lets go with the swing's speed
            } else {
                vy += g * dt
                card.fallX += vx * dt
                card.fallY += vy * dt
                th += om * dt
                if (card.fallY > (card.Window.height || 1500) + w) { stop(); card.visible = false; card.fell() }
            }
            card.fallAngle = th * 180 / Math.PI
        }
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
                name: card.row.icon || ""
                sourceSize: Qt.size(card.iconSize * 2, card.iconSize * 2)
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
