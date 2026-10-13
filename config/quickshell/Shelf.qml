import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Shelf: a temporary dock for files (like Dropover/Yoink on macOS).
// Drag a file to the top edge of the screen (center) -> the shelf opens -> drop the file on it.
// Files can be dragged from the shelf into another app (a successful drop removes them from the shelf). The shelf closes by itself when the cursor leaves.
// Files are not copied, the shelf only holds paths. State is in memory (reset when Quickshell restarts).
// Keyboard: qs ipc call shelf toggle  (keeps the shelf open until you close it)  /  qs ipc call shelf clear
Scope {
    id: shelf
    property var items: []             // file:// URLs
    property bool open: false
    property bool pinned: false        // a shelf opened via IPC doesn't close by itself
    property int dragging: 0           // outgoing drags in progress (the shelf must not close mid-drag)
    readonly property bool busy: pinned || dragging > 0 || card.hovered || dropArea.containsDrag || trigger.containsDrag || triggerHover.hovered

    function add(urls) {
        const cur = shelf.items.slice()
        for (const u of urls) {
            const s = u.toString()
            if (s.startsWith("file://") && cur.indexOf(s) < 0) cur.push(s)
        }
        shelf.items = cur
    }
    function remove(url) { shelf.items = shelf.items.filter(u => u !== url) }
    function clear() { shelf.items = [] }
    function name(url) { return decodeURIComponent(url.split("/").pop()) }
    function ext(url) {
        const n = name(url)
        const i = n.lastIndexOf(".")
        return i > 0 ? n.slice(i + 1).toLowerCase() : ""
    }
    function isImage(url) { return ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"].indexOf(ext(url)) >= 0 }

    property bool dragOpen: false      // opened by a drag (not the mouse): the trigger then covers the whole bar
    onBusyChanged: if (!busy && open) closeTimer.restart()
    onOpenChanged: { if (open) { if (!busy) closeTimer.restart() } else { dragOpen = false } }
    Timer { id: hoverOpen; interval: 250; onTriggered: if (triggerHover.hovered) shelf.open = true }
    // Short delay: moving the cursor from the top edge to the shelf doesn't close it
    Timer { id: closeTimer; interval: 120; onTriggered: if (!shelf.busy) shelf.open = false }

    IpcHandler {
        target: "shelf"
        function toggle(): void { shelf.pinned = !shelf.open || !shelf.pinned; shelf.open = shelf.pinned }
        function clear(): void { shelf.clear() }
    }

    // Invisible trigger at the top edge (center): a drag arriving here opens the shelf.
    PanelWindow {
        anchors { top: true }
        // The trigger covers the middle of the top bar: hovering or dragging over it opens the shelf, and dropping works on the bar already
        implicitWidth: shelf.open ? Math.max(360, card.width) : 360
        implicitHeight: Theme.barHeight   // full top bar height (the bar.s middle section is empty, so no button gets covered)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay   // Overlay: the bar (layer Top) must not cover the trigger
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Mouse at the top edge (lingering briefly) opens the shelf
        HoverHandler { id: triggerHover; onHoveredChanged: if (hovered) hoverOpen.restart() }

        DropArea {
            id: trigger
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: drag => { drag.accepted = true; shelf.dragOpen = true; shelf.open = true }
            onDropped: drop => { if (drop.hasUrls) { shelf.add(drop.urls); drop.acceptProposedAction() } }
        }
    }

    PanelWindow {
        visible: shelf.open
        anchors { top: true }
        margins { top: Theme.barHeight }   // attached to the top bar
        implicitWidth: card.width
        implicitHeight: card.height
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: card
            property bool hovered: hover.hovered
            // 4 files fit comfortably; width grows up to 6, after that the list scrolls (mouse wheel / two fingers)
            function chipsW(n) { return n * 64 + (n - 1) * 10 }
            width: 16 + flick.width + 12 + 56 + 16
            height: 74
            radius: 10
            color: "#000000"
            // Square top corners: the shelf continues the top bar
            Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: parent.radius; color: parent.color }

            HoverHandler { id: hover }

            DropArea {
                id: dropArea
                anchors.fill: parent
                keys: ["text/uri-list"]
                onEntered: drag => { drag.accepted = true }
                onDropped: drop => {
                    if (drop.hasUrls) { shelf.add(drop.urls); drop.acceptProposedAction() }
                }
            }

            Row {
                visible: shelf.items.length === 0
                anchors.centerIn: parent
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.g("download")
                    color: Theme.primary
                    font { family: Icons.family; pixelSize: 16 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DROP FILES HERE"
                    color: Theme.primary
                    font { family: Theme.font; pixelSize: 11; letterSpacing: 1 }
                }
            }

            Flickable {
                id: flick
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                height: 62
                width: Math.max(card.chipsW(4), Math.min(row.implicitWidth, card.chipsW(6)))
                contentWidth: row.implicitWidth
                contentHeight: height
                clip: true
                interactive: false
                WheelHandler {
                    onWheel: event => {
                        const d = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
                        flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - d))
                    }
                }

            Row {
                id: row
                spacing: 10

                Repeater {
                    model: shelf.items
                    delegate: Item {
                        id: chip
                        required property string modelData
                        width: 64
                        height: 62

                        // Drag: the file goes to another app (text/uri-list)
                        Item {
                            id: dragSource
                            anchors.fill: parent
                            Drag.active: ma.drag.active
                            Drag.hotSpot: Qt.point(width / 2, height / 2)
                            Drag.dragType: Drag.Automatic
                            Drag.supportedActions: Qt.CopyAction
                            Drag.mimeData: ({ "text/uri-list": chip.modelData + "\r\n" })
                            Drag.onActiveChanged: shelf.dragging += Drag.active ? 1 : -1
                            // Drop into another app succeeded -> remove from the shelf.
                            // The Wayland target doesn't always report the action (Ignore), so a drag that ends outside the shelf also removes.
                            Drag.onDragFinished: dropAction => {
                                if (dropAction !== Qt.IgnoreAction || !card.hovered) Qt.callLater(shelf.remove, chip.modelData)
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: ma.drag.active || chipHover.hovered ? Theme.hover : "transparent"
                            }
                            Rectangle {
                                id: thumb
                                width: 34; height: 34
                                anchors { top: parent.top; topMargin: 4; horizontalCenter: parent.horizontalCenter }
                                radius: 6
                                color: Theme.sel
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    visible: shelf.isImage(chip.modelData)
                                    source: visible ? chip.modelData : ""
                                    sourceSize: Qt.size(68, 68)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !shelf.isImage(chip.modelData)
                                    text: shelf.ext(chip.modelData).toUpperCase().slice(0, 4) || "FILE"
                                    color: Theme.accent
                                    font { family: Theme.font; pixelSize: 11; bold: true }
                                }
                            }
                            Text {
                                anchors { top: thumb.bottom; topMargin: 3; left: parent.left; right: parent.right; leftMargin: 2; rightMargin: 2 }
                                text: shelf.name(chip.modelData)
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                                color: Theme.text
                                font { family: Theme.font; pixelSize: 10 }
                            }

                            HoverHandler { id: chipHover }
                            Item { id: dragDummy; visible: false }   // drag.target: the chip itself doesn't move, an image follows the cursor
                            MouseArea {
                                cursorShape: Qt.PointingHandCursor
                                id: ma
                                anchors.fill: parent
                                drag.target: dragDummy
                                // Drag image (chip following the cursor): grabbed in advance on press
                                onPressed: dragSource.grabToImage(res => { dragSource.Drag.imageSource = res.url })
                            }
                        }

                        // Remove from the shelf (doesn't delete the file)
                        Rectangle {
                            visible: chipHover.hovered && !ma.drag.active
                            width: 16; height: 16; radius: 8
                            anchors { top: parent.top; right: parent.right; topMargin: 0; rightMargin: 0 }
                            color: Theme.border
                            Text { anchors.centerIn: parent; text: "×"; color: Theme.text; font { family: Theme.font; pixelSize: 13 } }
                            MouseArea { cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: shelf.remove(chip.modelData) }
                        }
                    }
                }
            }
            }

            // Clear all
            Row {
                id: clearRow
                visible: shelf.items.length > 0
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: -8; rightMargin: 21 }
                spacing: 4
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.g("trash-2")
                    color: clearArea.containsMouse ? Theme.accent : Theme.primary
                    font { family: Icons.family; pixelSize: 10 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clear"
                    color: clearArea.containsMouse ? Theme.accent : Theme.primary
                    font { family: Theme.font; pixelSize: 10 }
                }
            }
            MouseArea {
                cursorShape: Qt.PointingHandCursor
                id: clearArea
                visible: shelf.items.length > 0
                anchors { fill: clearRow; margins: -4 }
                hoverEnabled: true
                onClicked: { shelf.clear(); shelf.pinned = false; shelf.open = false }   // Clear hides the shelf immediately
            }
        }
    }
}
