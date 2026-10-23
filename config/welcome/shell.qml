import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.kit

// Welcome to Nightdrive: what a new install still needs from you (signing in to Claude, then Tailscale, Mail, Deck…), each
// set up in a Claude session of its own. The list is `tasks`; `welcome` opens this at the first login and owns its state.
ShellRoot {
    id: shell
    FloatingWindow {
        id: win
        title: "Welcome to Nightdrive"
        implicitWidth: 640
        implicitHeight: 690
        color: c.bg
        onClosed: Qt.quit()

        AppLook { id: c }
        readonly property QtObject look: c
        readonly property string dir: Quickshell.shellDir
        readonly property string setupCmd: Quickshell.env("HOME") + "/.config/hypr/scripts/claude-setup"

        // The list, read again every few seconds: a session that ends, or a setup done elsewhere, shows by itself
        property var tasks: []
        property int current: 0
        readonly property bool claudeIn: tasks.length > 0 && tasks[0].id === "claude" && tasks[0].done
        readonly property bool finished: tasks.length > 0 && tasks.every(t => t.done || t.mark === "skipped")
        Process {
            id: lister
            command: [win.dir + "/tasks"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { win.tasks = JSON.parse(text) } catch (e) { return }
                    if (!win.picked) win.current = win.firstOpen()
                    win.picked = true
                }
            }
        }
        function refresh() { if (!lister.running) lister.running = true }
        Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: win.refresh() }
        // After an action, its result soon rather than at the next round
        Timer { id: soon; interval: 800; onTriggered: win.refresh() }

        // The first open row is picked once, at the start; after that the keyboard's place stays where you put it
        property bool picked: false
        function firstOpen() {
            const i = tasks.findIndex(t => !t.done && t.mark !== "skipped")
            return i < 0 ? 0 : i
        }

        function run(argv) { Quickshell.execDetached(argv); soon.restart() }
        // Enter on a row: its terminal to the front while it runs; without Claude, the steps to do by hand; else its setup
        function activate(i) {
            const t = tasks[i]
            if (!t) return
            current = i
            if (t.id === "claude" && t.done) return
            if (t.running) run([setupCmd, "focus", t.id])
            else if (t.id !== "claude" && !claudeIn && !t.done) { if (t.help) run(["xdg-open", t.help]) }
            else {
                if (t.mark === "skipped") run([setupCmd, "mark", t.id])
                run(t.setup)
            }
        }
        // s: put aside, or back
        function skip(i) {
            const t = tasks[i]
            if (!t || t.done || t.running) return
            run(t.mark === "skipped" ? [setupCmd, "mark", t.id] : [setupCmd, "mark", t.id, "skipped"])
        }
        // Esc: Skip for now (what isn't done is put aside) or, all done or skipped, Finish. Either way logins stop asking.
        function close() {
            Quickshell.execDetached([dir + "/welcome", "skip-rest"])
            Qt.quit()
        }

        IpcHandler {
            target: "welcome"
            function refresh(): void { win.refresh() }
            function rows(): string { return JSON.stringify(win.tasks) }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                const k = e.key
                if (e.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.AltModifier)) {
                    if (k === Qt.Key_Q || k === Qt.Key_W) Qt.quit()     // later: the next login reminds
                    return
                }
                if (k === Qt.Key_Down || k === Qt.Key_J) win.current = Math.min(win.current + 1, win.tasks.length - 1)
                else if (k === Qt.Key_Up || k === Qt.Key_K) win.current = Math.max(win.current - 1, 0)
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) win.activate(win.current)
                else if (k === Qt.Key_S) win.skip(win.current)
                else if (k === Qt.Key_Escape) win.close()
                else return
                e.accepted = true
            }

            Column {
                id: head
                x: 40; y: 40
                width: parent.width - 80
                spacing: 16
                AppTitle { c: win.look; text: "Welcome to Nightdrive"; pixelSize: 24 }
                Text {
                    width: parent.width; wrapMode: Text.Wrap; lineHeight: 1.25
                    color: c.text; font.family: c.font; font.pixelSize: 13
                    text: "Your new computer is almost ready. To get the most out of Nightdrive, we recommend setting things up "
                        + "with Claude Code. If you don't have Claude, or want to skip for now, you can run this later from the "
                        + "launcher › System › Set up Nightdrive."
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
                model: win.tasks
                currentIndex: win.current
                highlightMoveDuration: 0
                delegate: TaskRow {
                    required property var modelData
                    c: win.look
                    task: modelData
                    selected: index === win.current
                    claudeIn: win.claudeIn
                    onActivated: win.activate(index)
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
                    KeyCap { c: win.look; keys: "↑  ↓"; tint: c.faint; anchors.verticalCenter: parent.verticalCenter }
                    AppKeyAction {
                        c: win.look
                        visible: !(win.tasks[win.current] || {}).done && !(win.tasks[win.current] || {}).running
                        keys: "s"; label: (win.tasks[win.current] || {}).mark === "skipped" ? "Don't skip" : "Skip this"
                        onClicked: win.skip(win.current)
                    }
                }
                AppKeyAction {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    c: win.look
                    keys: "esc"; label: win.finished ? "Finish" : "Skip for now"
                    color: win.finished ? c.primary : c.dim
                    onClicked: win.close()
                }
            }
        }
    }
}
