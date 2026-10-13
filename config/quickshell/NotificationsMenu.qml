import QtQuick
import Quickshell

// Hamburger menu: notifications (mako's history + do-not-disturb toggle), ⌘Esc / F3.
// The power actions (lock, suspend, log out, reboot, shut down) live in the launcher (⌘Space › Power).
// Notifications: `makoctl history -j` (summary, app and body text; mako doesn't store a timestamp). "Clear" doesn't empty mako's
// history; it stores the id of the latest notification (~/.cache/qs-notif-cleared) and everything older is hidden.
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 4

    property var items: []             // [{ id, summary, app }], newest first
    property int clearedId: 0
    property bool dnd: false
    signal close()

    readonly property string clearedFile: Quickshell.env("HOME") + "/.cache/qs-notif-cleared"
    readonly property var visibleItems: items.filter(n => n.id > clearedId).slice(0, 6)

    function parse(t) {
        try {
            return JSON.parse(t).map(n => ({ id: n.id, summary: n.summary || "", app: n.app_name || "", entry: n.desktop_entry || "",
                                            body: (n.body || "").replace(/<[^>]*>/g, "").trim() }))
        } catch (e) { return [] }
    }
    function refresh() { histProc.running = true; modeProc.running = true }
    Component.onCompleted: { clearedProc.running = true; refresh() }

    Sh { id: clearedProc; command: ["cat", m.clearedFile]; onResult: t => { m.clearedId = parseInt(t) || 0 } }
    Sh { id: histProc; command: ["makoctl", "history", "-j"]; onResult: t => { m.items = m.parse(t) } }
    Sh { id: modeProc; command: ["makoctl", "mode"]; onResult: t => { m.dnd = t.indexOf("do-not-disturb") >= 0 } }
    Timer { id: after; interval: 300; onTriggered: m.refresh() }

    // Toggle on = notifications are shown; off = do not disturb (mako mode do-not-disturb)
    MenuHeader {
        width: parent.width; title: "Notifications"
        showToggle: true; checked: !m.dnd
        onToggled: { Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/dnd"]); after.restart() }
    }
    Divider { pad: 7 }

    Repeater {
        model: m.visibleItems
        Rectangle {
            required property var modelData
            width: m.width
            height: lines.implicitHeight + 14
            radius: 5
            color: rowArea.containsMouse ? Theme.hover : "transparent"
            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/focus-app", modelData.app, modelData.entry])
                    m.close()
                }
            }
            Column {
                id: lines
                anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 2
                Text {
                    width: parent.width
                    text: modelData.app.toUpperCase(); elide: Text.ElideRight; color: Theme.primary
                    font { family: Theme.font; pixelSize: 9; weight: Font.Light; letterSpacing: 0.6 }
                }
                Text {
                    width: parent.width
                    text: modelData.summary; elide: Text.ElideRight; color: Theme.text
                    font { family: Theme.font; pixelSize: 13 }
                }
                Text {
                    visible: modelData.body !== ""
                    width: parent.width
                    text: modelData.body; color: Theme.dim; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: 11 }
                }
            }
        }
    }
    Text {
        visible: m.visibleItems.length === 0
        width: parent.width; height: 30; leftPadding: 10; verticalAlignment: Text.AlignVCenter
        text: "No notifications"; color: Theme.dim
        font { family: Theme.font; pixelSize: 12 }
    }
    Divider {}
    MenuRow {
        // always visible; greyed out and not clickable when there are no notifications
        enabled: m.visibleItems.length > 0
        opacity: enabled ? 1 : 0.4
        width: parent.width; icon: "trash-2"; action: true; label: "Clear"
        onClicked: {
            if (!enabled) return
            const top = m.items.length ? m.items[0].id : m.clearedId
            Quickshell.execDetached(["bash", "-c", 'mkdir -p "$(dirname "$2")"; printf %s "$1" > "$2"', "_", String(top), m.clearedFile])
            m.clearedId = top
        }
    }
}
