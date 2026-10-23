import QtQuick

// The keys of a window, shown by ? or Ctrl+? (GNOME's key for an app's shortcuts) until any other key. The window passes
// its key events to pressed(): the keys its own handlers leave alone (Ctrl+? among them, and ? from where nothing takes
// it). No ⌘ hold: ⌘ drags windows and starts the apps' shortcuts, so a hold showed the sheet by accident. Nightdrive's apps
// (Mail, Deck) share it: each links it into its own app/ folder, with KeyCap.qml.
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

    readonly property var modifierKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R]
    function pressed(e) {
        if (e.key === Qt.Key_Question) { shown = !shown; e.accepted = true }
        else if (modifierKeys.indexOf(e.key) < 0) shown = false       // Shift, on the way to ?, keeps it
    }

    anchors.fill: parent
    visible: shown
    color: root.c.scrim
    // A click outside the keys closes them; one on them keeps them
    TapHandler { onTapped: root.shown = false }
    Rectangle {
        TapHandler {}
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
                            spacing: 20
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
