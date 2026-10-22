import QtQuick

// The keys of a window, shown while ⌘ (Super) is held, or after ?, until any key. The window passes its key events to
// pressed() and released(); any other key in between cancels the hold, so ⌘ shortcuts stay quiet.
Rectangle {
    id: root
    required property QtObject c
    property var groups: []             // [{ title, keys: [[key, what], …] }, …]
    // As many columns as show the keys largest (and fill every row): all side by side in a wide, low window, one column
    // in a narrow one, two when that fits as well; what still doesn't fit is drawn smaller, so it all shows
    readonly property int columns: {
        const n = groupRows.count
        let best = Math.min(2, n), bestScale = 0
        for (let cols = 1; cols <= n; cols++) {
            if (n % cols !== 0) continue        // full rows only: no group left on a row of its own
            let w = 0, h = 0
            for (let r = 0; r < n; r += cols) {
                let rowH = 0
                for (let i = r; i < Math.min(n, r + cols); i++) {
                    const g = groupRows.itemAt(i)
                    if (!g) return best
                    w = Math.max(w, g.implicitWidth); rowH = Math.max(rowH, g.implicitHeight)
                }
                h += rowH
            }
            const rows = Math.ceil(n / cols)
            const sc = Math.min(1, (width - 32) / (cols * w + (cols - 1) * grid.columnSpacing + 80),
                                   (height - 32) / (h + (rows - 1) * grid.rowSpacing + 72))
            if (sc > bestScale + 0.001 || sc >= 1 && cols === 2) { best = cols; bestScale = sc }
        }
        return best
    }
    property bool shown: false
    readonly property int hold: 500     // ms ⌘ is held before the keys show

    function isSuper(k) { return k === Qt.Key_Super_L || k === Qt.Key_Super_R || k === Qt.Key_Meta }
    function pressed(e) {
        if (isSuper(e.key)) { if (!e.isAutoRepeat) timer.restart() }
        else { timer.stop(); if (e.key !== Qt.Key_Question) shown = false }
    }
    function released(e) { if (isSuper(e.key)) { timer.stop(); shown = false } }
    Timer { id: timer; interval: root.hold; onTriggered: root.shown = true }

    anchors.fill: parent
    visible: shown
    color: root.c.scrim
    Rectangle {
        anchors.centerIn: parent
        width: grid.implicitWidth + 80
        height: grid.implicitHeight + 72
        scale: Math.min(1, (root.width - 32) / width, (root.height - 32) / height)
        radius: 14
        color: root.c.solid
        border.color: root.c.line
        Grid {
            id: grid
            anchors.centerIn: parent
            columns: root.columns
            columnSpacing: 56
            rowSpacing: 32
            Repeater {
                id: groupRows
                model: root.groups
                delegate: Column {
                    id: group
                    required property var modelData
                    property real keyWidth: 0       // the group's widest keys: the descriptions start right after them
                    spacing: 10
                    Text { text: modelData.title; color: root.c.title; font.family: root.c.font; font.pixelSize: 13; font.weight: Font.Medium; bottomPadding: 4 }
                    Repeater {
                        model: modelData.keys
                        delegate: Row {
                            required property var modelData
                            spacing: 10
                            Item {
                                width: group.keyWidth; height: 22
                                KeyCap {
                                    anchors.verticalCenter: parent.verticalCenter; c: root.c; keys: modelData[0]; tint: root.c.accent
                                    onImplicitWidthChanged: group.keyWidth = Math.max(group.keyWidth, implicitWidth)
                                }
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; color: root.c.dim; font.family: root.c.font; font.pixelSize: 12 }
                        }
                    }
                }
            }
        }
    }
}
