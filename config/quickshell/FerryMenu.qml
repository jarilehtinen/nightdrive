import QtQuick
import Quickshell

// Ferry (hypr/scripts/ferry): a mailbox between this computer and the phone. Files dropped here (or on the bar icon) and
// the clipboard sent with Send Clipboard wait in the box for the phone, which gets a notification; what the phone sent is
// listed too: a click copies a text or opens a file, a file can be dragged out, and × takes an item out of the box. The
// phone's page is the address at the bottom (a click copies it) or its QR code.
Column {
    id: m
    width: parent ? parent.width : 340
    spacing: 8
    readonly property int preferredWidth: 340
    signal close()

    readonly property string ferry: Quickshell.env("HOME") + "/.config/hypr/scripts/ferry"
    property var st: null              // `ferry list`: { on, tailscale, url, serving, push, items: [{ id, to, kind, … }] }
    readonly property var items: st ? st.items : []
    readonly property var fromPhone: items.filter(i => i.to === "computer").reverse()
    readonly property var toPhone: items.filter(i => i.to === "phone").reverse()
    property string flash: ""          // what says "copied" / "sent" for a moment: an item's id, "url" or "clipboard"
    property string qr: ""             // the QR code's SVG while it's shown
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
    Component.onCompleted: refresh()
    Timer { interval: 2000; repeat: true; running: true; onTriggered: m.refresh() }
    Timer { id: soon; interval: 400; onTriggered: m.refresh() }
    Timer { id: flashTimer; interval: 1500; onTriggered: m.flash = "" }

    Sh {
        id: listProc
        command: [m.ferry, "list"]
        onResult: text => {
            try { m.st = JSON.parse(text) } catch (e) { return }
            // Seen once the menu shows them: the bar's count goes
            if (m.st.items.some(i => i.to === "computer" && !i.seen)) seenProc.running = true
        }
    }
    Sh { id: seenProc; command: [m.ferry, "seen"]; onResult: TopBar.refresh("ferry") }
    Sh {
        id: qrProc
        command: [m.ferry, "qr"]
        onResult: text => m.qr = text.trim()
    }

    MenuHeader { width: parent.width; title: "Ferry"; subtitle: m.st && m.st.push > 0 ? "phone notified" : "" }

    // Files for the phone: dropped here, or on the bar icon (modules.jsonc "drop"), which also opens this menu
    Rectangle {
        width: parent.width
        height: 58
        radius: 8
        color: drop.containsDrag ? Theme.sel : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.07)
        border { width: 1; color: drop.containsDrag ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35) }
        Row {
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.g("arrow-down-to-line")
                color: Theme.primary
                font { family: Icons.family; pixelSize: 16 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "DROP FILES FOR THE PHONE"
                color: Theme.primary
                font { family: Theme.font; pixelSize: 11; letterSpacing: 1 }
            }
        }
        DropArea {
            id: drop
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: drag => { drag.accepted = true }
            onDropped: d => {
                const paths = Array.from(d.urls, u => u.toString()).filter(u => u.startsWith("file://")).map(u => decodeURIComponent(u.slice(7)))
                if (paths.length) { m.run(["add"].concat(paths)); d.acceptProposedAction() }
            }
        }
    }

    MenuRow {
        width: parent.width
        icon: "clipboard-paste"
        action: true
        label: "Send Clipboard"
        detail: m.flash === "clipboard" ? "sent" : ""
        onClicked: { m.run(["send-clipboard"]); m.flashOn("clipboard") }
    }

    Repeater {
        model: [{ title: "From the phone", list: m.fromPhone }, { title: "Waiting for the phone", list: m.toPhone }]
        delegate: Column {
            id: sec
            required property var modelData
            visible: modelData.list.length > 0
            width: m.width
            spacing: 2
            MenuSection { title: sec.modelData.title; bottomPadding: 4 }
            // One item: a text (a click copies it) or a file (a click opens it, and it can be dragged into another app)
            Repeater {
                model: sec.modelData.list
                delegate: MenuRow {
                    id: r
                    required property var modelData
                    readonly property bool isFile: modelData.kind === "file"
                    width: sec.width
                    icon: !isFile ? "text" : /^image\//.test(modelData.type || "") ? "image" : "file"
                    label: isFile ? modelData.name : modelData.text.replace(/\s+/g, " ").trim()
                    detail: m.flash === modelData.id ? "copied" : m.ago(modelData.time)
                    hoverCheckIcon: "x"
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
                    // × at the right edge: out of the box (a file from the phone stays in Downloads)
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
    }

    Text {
        visible: m.st !== null && m.items.length === 0
        width: parent.width
        wrapMode: Text.Wrap
        text: "Empty"
        color: Theme.dim
        font { family: Theme.font; pixelSize: 12 }
    }

    // Why the phone can't get here, if it can't
    Text {
        readonly property string why: !m.st ? ""
            : !m.st.on ? "Ferry's server isn't running. Turn it on: launcher › System › Install › Plugins › Ferry."
            : !m.st.tailscale ? "Tailscale is off: the phone can't reach this computer."
            : !m.st.serving ? "Not on the tailnet yet. Run once: sudo tailscale set --operator=$USER, then ~/.config/hypr/scripts/ferry enable"
            : ""
        visible: why !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: why
        color: Theme.warning
        font { family: Theme.font; pixelSize: 12 }
    }

    Divider { padBottom: 6 }
    MenuRow {
        visible: m.st !== null && m.st.url !== ""
        width: parent.width
        icon: "smartphone"
        label: m.st ? m.st.url.replace(/^https:\/\//, "") : ""
        detail: m.flash === "url" ? "copied" : ""
        hoverCheckIcon: "copy"
        onClicked: { Quickshell.execDetached(["wl-copy", m.st.url]); m.flashOn("url") }
    }
    MenuRow {
        visible: m.st !== null && m.st.url !== ""
        width: parent.width
        icon: "qr-code"
        label: m.qr !== "" ? "Hide QR code" : "QR code for the phone"
        onClicked: { if (m.qr !== "") m.qr = ""; else qrProc.running = true }
    }
    // Dark modules on white: the iPhone camera reads it from the screen
    Rectangle {
        visible: m.qr !== ""
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
}
