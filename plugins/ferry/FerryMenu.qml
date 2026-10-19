import QtQuick
import QtQuick.Shapes
import Quickshell
import qs

// Ferry (bin/ferry): a mailbox between this computer and the owner's other devices (the phone, another
// computer's Ferry page). Files dropped here (or on the bar icon, which opens this menu, or chosen with a click on the
// empty box's drop zone) and the clipboard sent with Send Clipboard wait in the box for them; a moment's "Sent" over the
// list says so, and the menu lists only what the other devices sent here: a click copies a text or opens a file, a file
// can be dragged out, and × takes an item out of the box. Add Device shows the page's QR code and its address (a click
// copies it).
Column {
    id: m
    width: parent ? parent.width : 340
    spacing: 12
    readonly property int preferredWidth: 340
    signal close()

    // The plugin's own command, next to this file (a plugin's menu is loaded from its folder; `import qs` brings the
    // shared parts: Theme, MenuRow, Sh…)
    readonly property string ferry: decodeURIComponent(Qt.resolvedUrl("bin/ferry").toString().replace(/^file:\/\//, ""))
    property var st: null              // `ferry list`: { on, tailscale, url, serving, push, items: [{ id, to, kind, … }] }
    readonly property var items: st ? st.items : []
    readonly property var received: items.filter(i => i.to === "computer").reverse()
    property var waiting: null         // ids of the items waiting for the other devices, as last listed (null: not yet)
    property string sent: ""           // what was just sent ("2 files"), over the list for a moment
    property string flash: ""          // what says "copied" for a moment: an item's id or "url"
    property bool adding: false        // Add Device: the QR code and the address
    property string qr: ""             // the QR code's SVG once made
    property int dragging: 0           // files being dragged out: shell.qml lets the drop through to the windows below

    function refresh() { listProc.running = true }
    function run(args) { Quickshell.execDetached([m.ferry].concat(args)); soon.restart() }
    function flashOn(what) { m.flash = what; flashTimer.restart() }
    function ago(t) {
        const s = Date.now() / 1000 - t
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + " min" : s < 86400 ? Math.floor(s / 3600) + " h" : Math.floor(s / 86400) + " d"
    }
    function act(it) {
        if (it.kind === "text") { m.run(["copy", it.id]); m.flashOn(it.id) }
        else { m.run(["open", it.id]); m.close() }
    }
    function showSent(list) {
        const files = list.filter(i => i.kind === "file").length
        m.sent = files === list.length ? (list.length === 1 ? list[0].name : list.length + " files")
               : files === 0 ? (list.length === 1 ? "Text" : list.length + " texts")
               : list.length + " items"
        sentTimer.restart()
    }
    Component.onCompleted: refresh()
    Timer { interval: 2000; repeat: true; running: true; onTriggered: m.refresh() }
    Timer { id: soon; interval: 400; onTriggered: m.refresh() }
    Timer { id: flashTimer; interval: 1500; onTriggered: m.flash = "" }
    Timer { id: sentTimer; interval: 1500; onTriggered: m.sent = "" }

    Sh {
        id: listProc
        command: [m.ferry, "list", "--json"]
        onResult: text => {
            try { m.st = JSON.parse(text) } catch (e) { return }
            // Just sent: new since the last listing, or on opening the last few seconds' (a drop on the bar icon opens
            // the menu while it sends), whoever sent it (Send Clipboard, a drop here or on the icon, `ferry add`)
            const out = m.st.items.filter(i => i.to !== "computer")
            const fresh = m.waiting === null ? out.filter(i => Date.now() / 1000 - i.time < 5) : out.filter(i => m.waiting.indexOf(i.id) < 0)
            m.waiting = out.map(i => i.id)
            if (fresh.length) m.showSent(fresh)
            // Seen once the menu shows them: the bar's count goes
            if (m.st.items.some(i => i.to === "computer" && !i.seen)) seenProc.running = true
        }
    }
    Sh { id: seenProc; command: [m.ferry, "seen"]; onResult: TopBar.refresh("ferry") }
    Sh {
        id: qrProc
        command: [m.ferry, "qr", "--svg"]
        onResult: text => m.qr = text.trim()
    }

    MenuHeader { width: parent.width; title: "Ferry" }

    // Why the other devices can't get here, if they can't
    Rectangle {
        readonly property string why: !m.st ? ""
            : !m.st.on ? "Ferry's server isn't running. Turn it on: launcher › System › Install › Plugins › Ferry."
            : !m.st.tailscale ? "Tailscale is off: your other devices can't reach this computer."
            : !m.st.serving ? "Not on the tailnet yet. Run once: sudo tailscale set --operator=$USER, then: ferry enable"
            : ""
        visible: why !== ""
        width: parent.width
        height: whyText.implicitHeight + 24
        radius: 8
        color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.08)
        Text {
            id: whyIcon
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: Icons.g("triangle-alert")
            color: Theme.warning
            font { family: Icons.family; pixelSize: 16 }
        }
        MenuNote {
            id: whyText
            anchors { left: whyIcon.right; leftMargin: 10; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            variant: "warning"
            text: parent.why
        }
    }

    // What the other devices sent, or with nothing, the drop zone; files dropped anywhere on it go to the other devices
    Item {
        id: content
        width: parent.width
        height: m.received.length ? list.height : 104

        Shape {
            visible: m.received.length === 0
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, pickArea.containsMouse ? 0.7 : 0.4)
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [4, 3]
                fillColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, pickArea.containsMouse ? 0.09 : 0.04)
                PathRectangle { x: 0.5; y: 0.5; width: content.width - 1; height: content.height - 1; radius: 8 }
            }
        }
        Column {
            visible: m.received.length === 0
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Icons.g("arrow-down-to-line")
                color: Theme.primary
                font { family: Icons.family; pixelSize: 20 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "DROP FILES TO SEND"
                color: Theme.primary
                font { family: Theme.font; pixelSize: 11; letterSpacing: 1 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Pick them up on any of your devices"
                color: Theme.dim
                font { family: Theme.font; pixelSize: 11 }
            }
        }

        // A click on the drop zone: a file dialog (several files at once); the menu closes for it and opens again with "Sent"
        MouseArea {
            id: pickArea
            visible: m.received.length === 0
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { Quickshell.execDetached([m.ferry, "pick"]); m.close() }
        }

        Column {
            id: list
            width: parent.width
            spacing: 2
            // One item: a text (a click copies it) or a file (a click opens it, and it can be dragged into another app)
            Repeater {
                model: m.received
                delegate: MenuRow {
                    id: r
                    required property var modelData
                    readonly property bool isFile: modelData.kind === "file"
                    width: list.width
                    icon: !isFile ? "text" : /^image\//.test(modelData.type || "") ? "image" : "file"
                    label: isFile ? modelData.name : modelData.text.replace(/\s+/g, " ").trim()
                    detail: m.flash === modelData.id ? "copied" : (modelData["from"] ? modelData["from"] + " · " : "") + m.ago(modelData.time)
                    // Not while it says "copied": the × would cover it as long as the mouse stays on the row
                    hoverCheckIcon: m.flash === modelData.id ? "" : "x"
                    onClicked: m.act(modelData)

                    Item {
                        id: dragSource
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: removeArea.left }
                        Drag.active: dragArea.drag.active
                        Drag.hotSpot: Qt.point(20, height / 2)
                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction
                        Drag.mimeData: ({ "text/uri-list": "file://" + encodeURI(r.modelData.path || "") + "\r\n" })
                        Drag.onActiveChanged: m.dragging += Drag.active ? 1 : -1
                        Drag.onDragFinished: m.close()
                        Item { id: dragDummy; visible: false }   // drag.target: the row stays, its image follows the cursor
                        // No hover of its own: the row underneath keeps its highlight and its × under the mouse
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            drag.target: r.isFile ? dragDummy : null
                            onPressed: if (r.isFile) r.grabToImage(res => { dragSource.Drag.imageSource = res.url })
                            onClicked: r.clicked()
                        }
                    }
                    // × at the right edge: out of the box (a received file stays in Downloads)
                    MouseArea {
                        id: removeArea
                        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                        width: 34
                        cursorShape: Qt.PointingHandCursor
                        onClicked: m.run(["remove", r.modelData.id])
                    }
                }
            }
        }

        // Files over the menu, then for a moment what was sent (a one-row list leaves room for the first line only)
        Rectangle {
            visible: drop.containsDrag || m.sent !== ""
            anchors.fill: parent
            radius: 8
            color: Qt.rgba(Theme.sel.r, Theme.sel.g, Theme.sel.b, 0.92)
            border { width: 1; color: drop.containsDrag ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) }
            Column {
                anchors.centerIn: parent
                spacing: 6
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.g(drop.containsDrag ? "arrow-down-to-line" : "circle-check")
                        color: Theme.accent
                        font { family: Icons.family; pixelSize: 16 }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1   // uppercase: no descenders
                        text: drop.containsDrag ? "DROP TO SEND" : "SENT"
                        color: Theme.accent
                        font { family: Theme.font; pixelSize: 11; letterSpacing: 1 }
                    }
                }
                Text {
                    visible: !drop.containsDrag && content.height >= 60
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, content.width - 24)
                    elide: Text.ElideMiddle
                    text: m.sent + " · ready on your devices"
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: 11 }
                }
            }
        }
        DropArea {
            id: drop
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: drag => { drag.accepted = m.dragging === 0 }   // not a row of this list dragged out
            onDropped: d => {
                const paths = Array.from(d.urls, u => u.toString()).filter(u => u.startsWith("file://")).map(u => decodeURIComponent(u.slice(7)))
                if (!paths.length) return
                m.run(["add"].concat(paths))
                m.showSent(paths.map(p => ({ kind: "file", name: p.replace(/\/+$/, "").split("/").pop() })))
                d.acceptProposedAction()
            }
        }
    }

    Row {
        width: parent.width
        spacing: 8
        MenuRow {
            width: (parent.width - parent.spacing) / 2
            icon: "clipboard-paste"
            action: true
            centered: true
            label: "Send Clipboard"
            onClicked: m.run(["send-clipboard"])
        }
        MenuRow {
            width: (parent.width - parent.spacing) / 2
            icon: "qr-code"
            action: true
            centered: true
            active: m.adding
            label: "Add Device"
            onClicked: { m.adding = !m.adding; if (m.adding && m.qr === "") qrProc.running = true }
        }
    }

    // Add Device: the page's QR code (dark modules on white: the iPhone camera reads it from the screen) and its address
    Column {
        visible: m.adding && m.st !== null && m.st.url !== ""
        width: parent.width
        spacing: 8
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 184; height: 184; radius: 8
            color: "white"
            Image {
                anchors { fill: parent; margins: 8 }
                source: m.qr !== "" ? "file://" + m.qr : ""
                sourceSize: Qt.size(336, 336)
                smooth: false
                cache: false
            }
        }
        MenuRow {
            width: parent.width
            icon: "copy"
            centered: true
            label: m.flash === "url" ? "Copied" : m.st ? m.st.url.replace(/^https:\/\//, "").replace(/\/$/, "") : ""
            onClicked: { Quickshell.execDetached(["wl-copy", m.st.url]); m.flashOn("url") }
        }
    }
}
