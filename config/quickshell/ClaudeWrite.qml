import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Claude writes: the preview next to the mouse after ⌘⇧C (hypr/scripts/claude-write, which reads the selection and the
// window). Claude's text shows here first, and goes in place of the selection only with Enter: Esc or a click outside
// cancels, ⌘⇧C again writes another version. In a terminal it is the command for what the selection asked, with a
// warning when it deletes, overwrites or needs root; Enter puts it on the command line, it doesn't run it.
//   qs ipc call write open <dir>   (dir: the script's selection and meta.json)
//   qs ipc call write again
//   qs ipc call write ask <dir>    another app's request (Mail's reply, plugins/mail): dir/meta.json { x, y (the
//                                  desktop's coordinates), sent (the line saying what goes to Claude), accept (Enter's
//                                  hint), draft, reply, cancel (commands, as lists) }. draft prints {text, sent} or
//                                  {error}; Enter writes dir/result and runs reply instead of pasting; cancel, if given,
//                                  runs on Esc or a click outside
// (Not named *Menu.qml: shell.qml treats those as top bar menus.)
PanelWindow {
    id: win
    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/claude-write"
    readonly property int maxChars: 8000   // a longer selection is sent only after an Enter: it may be more than meant

    property bool open: false
    property string dir: ""
    property var meta: ({})                // { addr, class, title, terminal, x, y, chars }
    property string selection: ""
    property string sent: ""               // what goes to Claude, in a line: the selection, or an app's own words
    property string phase: ""              // confirm | working | done | error
    property string result: ""
    property string warning: ""
    property string error: ""
    property int gen: 0                    // a draft that was cancelled or replaced answers into nothing

    function show(d) {
        dir = d
        metaFile.path = ""; metaFile.path = d + "/meta.json"
        selFile.path = ""; selFile.path = d + "/selection"
        try { meta = JSON.parse(metaFile.text()) } catch (e) { return }
        selection = meta.draft ? "" : selFile.text()
        sent = meta.draft ? meta.sent || "" : selection
        const f = Hyprland.focusedMonitor
        screen = (f && Quickshell.screens.find(s => s.name === f.name)) || Quickshell.screens[0]
        result = ""; warning = ""; error = ""
        open = true
        keys.forceActiveFocus()
        if (meta.chars > maxChars) phase = "confirm"
        else write()
    }
    function write() {
        gen++
        phase = "working"
        draft.running = false
        draft.myGen = gen
        draft.command = meta.draft || [script, "draft", dir]
        draft.running = true
    }
    function cancel() {
        if (open && meta.cancel) Quickshell.execDetached(meta.cancel)
        gen++; draft.running = false; open = false
    }
    function accept() {
        if (phase === "confirm") { write(); return }
        if (phase !== "done" || result === "") return
        open = false
        // The text to the script's folder (only you can read it), then the script puts it in place, or the app that
        // asked takes it from there
        const then = meta.reply || [script, "replace", dir]
        Quickshell.execDetached(["sh", "-c", 'umask 077; printf "%s" "$1" > "$2/result" && shift 2 && exec "$@"',
                                 "_", result, dir].concat(then))
    }

    FileView { id: metaFile; blockLoading: true; printErrors: false }
    FileView { id: selFile; blockLoading: true; printErrors: false }
    Sh {
        id: draft
        property int myGen: 0
        onResult: text => {
            if (myGen !== win.gen || !win.open) return
            let r = {}
            try { r = JSON.parse(text) } catch (e) { r = { error: "Claude's answer didn't come through" } }
            if (r.error) { win.error = r.error; win.phase = "error"; return }
            win.result = r.text || ""; win.warning = r.warning || ""; win.phase = "done"
            if (r.sent) win.sent = r.sent
        }
    }

    IpcHandler {
        target: "write"
        function open(dir: string): void { win.show(dir) }
        function again(): void { if (win.open && win.phase !== "confirm") win.write() }
        function ask(dir: string): void { win.show(dir) }
    }

    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "claude-write"

    MouseArea { anchors.fill: parent; onClicked: win.cancel() }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) win.cancel()
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) win.accept()
            else return
            e.accepted = true
        }
    }

    readonly property var keyGlyphs: ({ Enter: "corner-down-left", Cmd: "command", Shift: "arrow-big-up" })
    readonly property var hints: phase === "done" ? [{ keys: ["Enter"], text: meta.accept || (meta.terminal ? "Put on command line" : "Replace selection") },
                                                     { keys: ["Cmd", "Shift", "C"], text: "Write new" }, { keys: ["Esc"], text: "Cancel" }]
        : phase === "confirm" ? [{ keys: ["Enter"], text: "Send" }, { keys: ["Esc"], text: "Cancel" }]
        : phase === "error" ? [{ keys: ["Cmd", "Shift", "C"], text: "Try again" }, { keys: ["Esc"], text: "Close" }]
        : [{ keys: ["Esc"], text: "Cancel" }]

    // Below the mouse, kept on the screen
    readonly property real mx: (meta.x || 0) - (screen ? screen.x : 0)
    readonly property real my: (meta.y || 0) - (screen ? screen.y : 0)

    Rectangle {
        id: card
        width: Math.min(480, win.width - 32)
        height: body.implicitHeight + 32
        x: Math.max(16, Math.min(win.mx - 24, win.width - width - 16))
        y: win.my + 24 + height < win.height - 16 ? win.my + 24 : Math.max(16, win.my - 24 - height)
        radius: 12
        color: Theme.launcherBg
        border { color: Theme.primary; width: 2 }
        MouseArea { anchors.fill: parent }

        Column {
            id: body
            x: 16; y: 16
            width: parent.width - 32
            spacing: 10

            Row {
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.g(win.meta.terminal ? "terminal" : "sparkles")
                    color: Theme.accent
                    font { family: Icons.family; pixelSize: 16 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.meta.terminal ? "Claude writes the command" : "Claude writes"
                    color: Theme.title
                    font { family: Theme.font; pixelSize: 14; bold: true }
                }
            }

            // What was sent, so it's clear what left the machine
            Text {
                width: parent.width
                text: "Sent: " + win.sent.replace(/\s+/g, " ").trim()
                color: Theme.dim
                elide: Text.ElideRight
                font { family: Theme.font; pixelSize: 12 }
            }

            Text {
                visible: win.phase === "confirm"
                width: parent.width
                wrapMode: Text.Wrap
                text: (win.meta.chars || 0).toLocaleString() + " characters are selected. Enter sends them to Claude."
                color: Theme.warning
                font { family: Theme.font; pixelSize: 13 }
            }
            BusyDots { visible: win.phase === "working" }
            Text {
                visible: win.phase === "error"
                width: parent.width
                wrapMode: Text.Wrap
                text: win.error
                color: Theme.danger
                font { family: Theme.font; pixelSize: 13 }
            }
            Rectangle {
                visible: win.phase === "done"
                width: parent.width
                height: Math.min(resultText.implicitHeight, 320) + 20
                radius: 8
                color: Theme.card
                Flickable {
                    x: 10; y: 10
                    width: parent.width - 20; height: parent.height - 20
                    contentHeight: resultText.implicitHeight
                    clip: true
                    Text {
                        id: resultText
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: win.result
                        textFormat: Text.PlainText
                        color: Theme.text
                        font { family: win.meta.terminal ? "monospace" : Theme.font; pixelSize: 13 }
                    }
                }
            }
            Row {
                visible: win.phase === "done" && win.warning !== ""
                width: parent.width
                spacing: 8
                Text {
                    text: Icons.g("triangle-alert")
                    color: Theme.danger
                    font { family: Icons.family; pixelSize: 14 }
                }
                Text {
                    width: parent.width - 22
                    wrapMode: Text.Wrap
                    text: win.warning
                    color: Theme.danger
                    font { family: Theme.font; pixelSize: 13 }
                }
            }

            // The keys, framed like the launcher's footer: Lucide glyphs for Enter, ⌘ and ⇧ (the font's ⇧ is faint)
            Flow {
                width: parent.width
                topPadding: 2
                spacing: 14
                Repeater {
                    model: win.hints
                    Row {
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: caps.implicitWidth + 14; height: 22; radius: 6
                            color: "transparent"
                            border { width: 1; color: Theme.dim }
                            Row {
                                id: caps
                                anchors.centerIn: parent
                                spacing: 4
                                Repeater {
                                    model: modelData.keys
                                    Text {
                                        required property string modelData
                                        readonly property string glyph: win.keyGlyphs[modelData] || ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: glyph !== "" ? Icons.g(glyph) : modelData.length === 1 ? modelData : modelData.toLowerCase()
                                        color: Theme.dim
                                        font { family: glyph !== "" ? Icons.family : Theme.font
                                               pixelSize: glyph !== "" ? 12 : modelData.length === 1 ? 13 : 11 }
                                    }
                                }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            color: Theme.dim
                            font { family: Theme.font; pixelSize: 12 }
                        }
                    }
                }
            }
        }
    }
}
