import QtQuick
import Quickshell

// Claude usage: 5-hour session, week and per-model week (topbar/scripts/claude-usage, Claude Code's own sign-in).
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 10

    property var usage: null          // { plan, windows: [{ key, percent, resetsAt, model }], fetchedAt }
    property bool loaded: false
    signal close()

    function refresh() { proc.running = true }
    Component.onCompleted: refresh()
    Timer { interval: 5000; repeat: true; running: true; onTriggered: m.refresh() }

    Sh {
        id: proc
        command: [Quickshell.env("HOME") + "/.config/topbar/scripts/claude-usage"]
        onResult: text => {
            try { m.usage = JSON.parse(text) } catch (e) { m.usage = null }
            m.loaded = true
        }
    }

    function label(w) {
        if (w.key === "session") return "5-hour session"
        if (w.key === "weekly") return "Weekly"
        return "Weekly · " + (w.model || "model")
    }
    // "resets in 1h 28m" (under 24 h) or "resets Wed 01:00"
    function resets(iso) {
        const t = new Date(iso)
        if (isNaN(t)) return ""
        const d = Math.round((t - new Date()) / 1000)
        if (d <= 0) return "resetting now"
        if (d < 86400) {
            const h = Math.floor(d / 3600), mi = Math.floor(d % 3600 / 60)
            return "resets in " + (h > 0 ? h + "h " : "") + mi + "m"
        }
        return "resets " + Qt.formatDateTime(t, "ddd HH:mm")
    }

    MenuHeader { width: parent.width; title: "Claude usage"; subtitle: m.usage && m.usage.plan ? m.usage.plan : "" }

    MenuNote {
        visible: m.loaded && (!m.usage || !m.usage.windows || m.usage.windows.length === 0 || !!m.usage.error)
        text: m.usage && m.usage.error ? m.usage.error : "No usage data. Sign in to Claude Code (run claude) first."
    }

    Repeater {
        model: m.usage && m.usage.windows ? m.usage.windows : []
        delegate: Column {
            required property var modelData
            width: m.width
            spacing: 5
            Item {
                width: parent.width; height: 18
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: m.label(modelData)
                    color: Theme.text
                    font { family: Theme.font; pixelSize: 13 }
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: modelData.percent + "%"
                    color: modelData.percent > 95 ? Theme.danger : (modelData.percent > 90 ? Theme.warning : Theme.text)
                    font { family: Theme.font; pixelSize: 13; bold: true }
                }
            }
            Rectangle {
                width: parent.width; height: 6; radius: 3
                color: Theme.border
                Rectangle {
                    width: parent.width * Math.min(1, modelData.percent / 100)
                    height: parent.height; radius: 3
                    color: modelData.percent > 95 ? Theme.danger : (modelData.percent > 90 ? Theme.warning : Theme.accent)
                }
            }
            MenuNote { text: m.resets(modelData.resetsAt) }
        }
    }

    // 10 px above the button on top of the spacing, in place of a divider (a Column skips a zero-height spacer)
    Item {
        width: parent.width
        height: openRow.height + 10
        // A pill like Ferry's Send Clipboard: a soft wash of the theme colour, not a filled button
        Rectangle {
            id: openRow
            property bool navSelected: false
            readonly property bool navEnabled: true
            function navActivate() { openArea.clicked(null) }
            y: 10
            width: parent.width
            height: 36; radius: 18
            color: openArea.containsMouse ? Qt.lighter(Theme.sel, 1.3) : Theme.sel   // under the mouse just brighter
            border { width: 1; color: navSelected ? Theme.primary : Theme.border }
            Row {
                anchors.centerIn: parent
                spacing: 9
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.g("external-link")
                    color: Theme.accent
                    font { family: Icons.family; pixelSize: 16 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Open usage page"
                    color: Theme.accent
                    font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                }
            }
            MouseArea {
                id: openArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { Quickshell.execDetached(["xdg-open", "https://claude.ai/settings/usage"]); m.close() }
            }
        }
    }
}
