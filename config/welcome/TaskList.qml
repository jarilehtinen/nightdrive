import QtQuick
import qs
import qs.kit

// Welcome's list: what is still to set up, one row each (TaskRow). Enter sets the picked one up, with Claude or by hand
// as the first question was answered (shell.qml's activate); c changes that answer, s puts a row aside.
Item {
    id: root
    required property var app
    required property QtObject c
    readonly property var task: app.rows[app.current] || {}

    function key(e) {
        const k = e.key
        if (k === Qt.Key_Down || k === Qt.Key_J) app.current = Math.min(app.current + 1, app.rows.length - 1)
        else if (k === Qt.Key_Up || k === Qt.Key_K) app.current = Math.max(app.current - 1, 0)
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) app.activate(app.current)
        else if (k === Qt.Key_S) app.skip(app.current)
        else if (k === Qt.Key_C) app.choose(app.manual ? "claude" : "manual")
        else if (k === Qt.Key_Escape) app.close()
        else return false
        return true
    }

    Column {
        id: head
        x: 40; y: 40
        width: parent.width - 80
        spacing: 16
        AppTitle { c: root.c; text: "Welcome to Nightdrive"; pixelSize: 24 }
        Text {
            width: parent.width; wrapMode: Text.Wrap; lineHeight: 1.25
            color: root.c.text; font.family: root.c.font; font.pixelSize: 13
            text: root.app.manual
                ? "Your new computer is almost ready. Set each of these up here, one step at a time: Enter shows the "
                  + "steps. Skip what you don't need; launcher › System › Set up Nightdrive brings you back here later."
                : "Your new computer is almost ready. Sign in to Claude first, then Claude sets up each of these with "
                  + "you. Skip what you don't need; launcher › System › Set up Nightdrive brings you back here later."
        }
    }

    ListView {
        id: list
        x: 26; y: head.y + head.height + 24
        width: parent.width - 52
        height: foot.y - y - 16
        clip: true
        spacing: 2
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: root.app.rows
        currentIndex: root.app.current
        highlightMoveDuration: 0
        delegate: TaskRow {
            required property var modelData
            c: root.c
            task: modelData
            selected: index === root.app.current
            claudeIn: root.app.claudeIn
            manual: root.app.manual
            onActivated: root.app.activate(index)
        }
    }

    // The keys, for the mouse too
    Item {
        id: foot
        x: 40; y: parent.height - height - 28
        width: parent.width - 80
        height: 22
        Row {
            spacing: 20
            anchors.verticalCenter: parent.verticalCenter
            KeyCap { c: root.c; keys: "↑  ↓"; tint: root.c.faint; anchors.verticalCenter: parent.verticalCenter }
            AppKeyAction {
                c: root.c
                visible: !root.task.done && !root.task.running
                keys: "s"; label: root.task.mark === "skipped" ? "Don't skip" : "Skip this"
                onClicked: root.app.skip(root.app.current)
            }
            AppKeyAction {
                c: root.c
                keys: "c"; label: root.app.manual ? "I have Claude now" : "Set up by hand"
                onClicked: root.app.choose(root.app.manual ? "claude" : "manual")
            }
        }
        AppKeyAction {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            c: root.c
            keys: "esc"; label: root.app.finished ? "Finish" : "Skip for now"
            color: root.app.finished ? root.c.primary : root.c.dim
            onClicked: root.app.close()
        }
    }
}
