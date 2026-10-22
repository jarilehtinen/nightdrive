import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Nightdrive Mail: folders, thread list and the open thread, over notmuch.
ShellRoot {
    id: shell
    FloatingWindow {
        id: win
        title: "Mail"
        implicitWidth: 1440
        implicitHeight: 900
        color: c.bg
        // Closing the window (⌘W) quits Mail: a process left without its window would only look open to `nightmail`.
        onClosed: Qt.quit()

        // The look, in one place: the desktop's theme (Theme.qml, linked from Nightdrive's shell), with the terminal's
        // background and opacity behind the window, and a few shades derived from it for lines and quiet text.
        QtObject {
            id: c
            readonly property color bg: Theme.launcherBg
            readonly property color solid: Qt.rgba(bg.r, bg.g, bg.b, 1)
            readonly property color line: Qt.lighter(solid, 1.45)
            readonly property color hover: Theme.hover
            readonly property color sel: Theme.sel
            readonly property color text: Theme.text
            readonly property color body: Qt.lighter(text, 1.06)
            readonly property color dim: Theme.dim
            readonly property color faint: Qt.darker(dim, 1.33)
            readonly property color accent: Theme.accent
            readonly property color primary: Theme.primary
            readonly property color title: Theme.title
            readonly property color danger: Theme.danger
            // Behind a panel over the window (settings, Claude's question, the key sheet): the menus' background, dimmed
            readonly property color scrim: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.7)
            readonly property string font: Theme.font
        }

        Notmuch { id: nm }
        // For components in their own files, which don't see this file's ids.
        readonly property QtObject look: c
        readonly property QtObject mailer: nm

        // Settings (⌘,), kept in ~/.config/nightmail/settings.json.
        property var settings: ({ composeFloats: true, view: 0 })
        FileView {
            id: settingsFile
            path: Quickshell.env("HOME") + "/.config/nightmail/settings.json"
            watchChanges: true
            onFileChanged: reload()
            onLoaded: { try { win.settings = Object.assign({ composeFloats: true, view: 0 }, JSON.parse(text())) } catch (e) {} }
        }
        function setting(key, value) {
            const s = Object.assign({}, settings); s[key] = value; settings = s
            settingsFile.setText(JSON.stringify(s, null, 2) + "\n")
            if (key === "view") htmlMode = value     // the open thread shows the change at once
        }

        // `nightmail sync` asks for a reload once new mail is indexed; `nightmail new` opens an empty message.
        IpcHandler {
            target: "mail"
            function refresh(): void { win.reload(true) }
            function compose(): void { win.compose("new") }
            // A mailto: link (`nightmail mailto:…`, when Mail is the email app: launcher › Settings › Default apps)
            function mailto(url: string): void { win.compose("new", null, win.mailtoFields(url)) }
            // A notification's click and Reply button (lib/notify.py, through `nightmail show` and `reply`).
            // (Not "show": `qs ipc call` takes that word for its own command.)
            function openMessage(id: string): void { win.openMessage(id, null) }
            function replyTo(id: string): void { win.openMessage(id, () => win.compose("all")) }
            function claudeReply(id: string): void { win.openMessage(id, () => win.compose("claude")) }
            // The Claude writes card's Enter and Esc (`nightmail claude-reply`, `claude-cancel`)
            function claudeAnswer(json: string): void { const a = JSON.parse(json); composer.answered(a.gen, a.text, a.read) }
            function claudeCancel(gen: string): void { if (parseInt(gen) === composer.gen) composer.bodyEdit.forceActiveFocus() }
        }

        readonly property var folders: [
            { name: "Inbox", dir: "INBOX", query: "folder:/INBOX$/ and tag:inbox" },
            { name: "Sent", dir: "Sent", query: "folder:/Sent$/" },
            { name: "Drafts", dir: "Drafts", query: "folder:/Drafts$/" },
            // Archived before archive moved mail to the Archive folder: in the inbox's folder without the inbox tag.
            { name: "Archive", dir: "Archive", query: "folder:/Archive$/ or (folder:/INBOX$/ and not tag:inbox)" },
            { name: "Spam", dir: "Spam", query: "folder:/Spam$/" },
            { name: "Trash", dir: "Trash", query: "folder:/Trash$/" }
        ]
        readonly property int arrowStep: 80     // px an arrow key scrolls the message
        readonly property int headerHeight: 22  // the folders' title line and the list's search line
        readonly property int headerGap: 30     // from them to the first folder and the first message
        readonly property int undoDepth: 20     // steps ⌘Z can take back
        property int folder: 0
        property bool showFolders: true
        property int htmlMode: 0            // h cycles: 0 text, 1 HTML on the dark page, 2 HTML on light paper; each thread opens in settings.view
        property var account: ({ address: "" })
        property var threads: []
        property int current: -1
        property var messages: []
        property var unreadCounts: ({})

        function query() {
            const q = search.text.trim()
            return q === "" ? folders[folder].query : "(" + folders[folder].query + ") and (" + q + ")"
        }

        function reload(keep) {
            const id = keep && current >= 0 && threads[current] ? threads[current].thread : ""
            nm.search(query(), list => {
                threads = list
                let i = list.findIndex(t => t.thread === id)
                if (i < 0) i = list.length > 0 ? 0 : -1
                if (!keep || i !== current) open(i)
            })
            for (let f = 0; f < folders.length; f++) {
                const n = f
                nm.run(["count", "--output=threads", "(" + folders[f].query + ") and tag:unread"], t => {
                    const u = Object.assign({}, unreadCounts); u[n] = parseInt(t) || 0; unreadCounts = u
                })
            }
        }

        function open(i, then) {
            current = i
            htmlMode = settings.view
            if (i < 0) { messages = []; return }
            const t = threads[i]
            nm.show(t.thread, m => { if (threads[current] === t) { messages = m; if (then) then() } })
            if (t.tags.indexOf("unread") >= 0)
                nm.tag(["-unread"], "thread:" + t.thread, () => reload(true))
        }

        // Writing: mode "new", "reply" (to the sender), "all", "claude" (a reply Claude drafts) or "forward", all on the
        // thread's last message, or "resume" to write on the thread's draft. The thread is the open one, or msgs (a
        // message window's).
        function compose(mode, msgs, fields) {
            const all = msgs || messages
            if (composeWin.visible) return
            if (mode === "new") { composer.start("New message", fields || {}); showCompose(); return }
            if (mode === "resume") {
                const d = draft(all)
                if (!d) return
                nm.compose(["resume", d.id], r => {
                    if (r.error) { say(r.error); return }
                    composer.start("Draft", r)
                    // A reply's draft keeps ⌘⇧C, when the message it answers is here.
                    const answers = r.in_reply_to.replace(/[<>\s]/g, "")
                    if (answers && all.some(m => m.id === answers)) composer.replyId = answers
                    showCompose()
                })
                return
            }
            const last = all.filter(m => !m.draft).pop()
            if (!last) return
            if (mode === "forward") {
                nm.compose(["forward", last.id], r => {
                    if (r.error) { say(r.error); return }
                    composer.start("Forward", r)
                    composer.forwardId = last.id
                    showCompose()
                })
                return
            }
            nm.compose(["reply", last.id].concat(mode === "reply" ? [] : ["all"]), r => {
                if (r.error) { say(r.error); return }
                composer.start(mode === "reply" ? "Reply to sender" : "Reply", r)
                composer.replyId = last.id
                showCompose()
                if (mode === "claude") composer.rewrite()
            })
        }
        // mailto:a@b?cc=…&subject=…&body=… as the writing window's fields (RFC 6068)
        function mailtoFields(url) {
            const m = url.replace(/^mailto:/i, "").split("?")
            const f = { to: decodeURIComponent(m[0] || "") }
            for (const kv of (m[1] || "").split("&")) {
                const i = kv.indexOf("="), k = kv.slice(0, i).toLowerCase()
                if (i > 0 && ["to", "cc", "subject", "body"].indexOf(k) >= 0) {
                    const v = decodeURIComponent(kv.slice(i + 1).replace(/\+/g, " "))
                    f[k] = k === "to" && f.to ? f.to + ", " + v : v
                }
            }
            return f
        }
        // The addresses to complete from are read again each time, so the newest are there.
        function showCompose() {
            composeWin.opening = true; composeWin.visible = true
            nm.addresses(list => composer.book = list.filter(a => a.address !== account.address))
        }
        // The open thread's draft, newest first, if it has one.
        function draft(msgs) { return (msgs || messages).filter(m => m.draft).pop() }

        // A thread in a window of its own (a double click or Enter in the list): it floats or tiles like the writing
        // window, and keeps its own keys.
        function openWindow(i) {
            const t = threads[i]
            if (!t) return
            nm.show(t.thread, m => { if (m.length) messageWindow.createObject(shell, { msgs: m }) })
        }

        // Claude writes the reply (Compose.qml asks): the desktop's Claude writes card opens by (x, y) in the writing
        // window and runs compose.py through `nightmail claude-draft`: the thread up to the message answered with the
        // draft, or the selected text alone. Its Enter comes back through claudeAnswer().
        function suggest(request, x, y) {
            nm.nightmail(["ask-claude", composeWin.title, String(Math.round(x)), String(Math.round(y)), JSON.stringify(request)],
                         t => { if (t.trim()) { try { composer.failed = true; composer.status = JSON.parse(t).error } catch (e) {} } })
        }

        function sendMail(f) {
            composer.busy = true; composer.failed = false; composer.status = "Sending…"
            nm.compose(["send", JSON.stringify(f)], r => {
                composer.busy = false
                if (r.error) { composer.failed = true; composer.status = r.error; return }
                composeWin.done = true; composeWin.visible = false
                // The answered or forwarded message gets the flag phones and webmail show too (after the next sync).
                if (composer.replyId) nm.tag(["+replied"], "id:\"" + composer.replyId + "\"")
                if (composer.forwardId) nm.tag(["+passed"], "id:\"" + composer.forwardId + "\"")
                reload(true)
            })
        }

        // ⌘S, or closing a message saved before: the copy in Drafts is replaced with this one.
        function saveDraft(f, close) {
            if (close) { composeWin.done = true; composeWin.visible = false }
            nm.compose(["draft", JSON.stringify(f)], r => {
                if (r.error) { composer.failed = true; composer.status = r.error; if (close) composeWin.visible = true; return }
                if (!close) { composer.draftId = r.id; composer.failed = false; composer.status = "Saved in Drafts" }
                reload(true)
            })
        }
        function dismissCompose() { composeWin.done = true; composeWin.visible = false }

        // An attachment opens in the app the desktop picks for it, or is saved in the downloads folder.
        function openPart(msg, f) {
            say("Opening " + f.name + "…")
            nm.part("open", msg.id, f.part, f.name, r => {
                if (r.error) { say(r.error); return }
                Qt.openUrlExternally("file://" + r.path)
                say("")
            })
        }
        function savePart(msg, f) {
            nm.part("save", msg.id, f.part, f.name, r => say(r.error || "Saved to " + r.path.replace(Quickshell.env("HOME"), "~")))
        }
        function size(n) {
            if (n < 0) return ""
            if (n < 1024) return n + " B"
            if (n < 1024 * 1024) return Math.round(n / 1024) + " kB"
            return (n / 1024 / 1024).toFixed(1) + " MB"
        }

        function scrollMessage(dy) {
            reader.cancelFlick()
            reader.contentY = Math.max(0, Math.min(reader.contentHeight - reader.height, reader.contentY + dy))
        }

        // Delete, archive and spam move the open thread to the account's Trash, Archive or Spam folder (on the server too,
        // at the next sync, so a phone sees it the same way and the server's spam filter learns from it) and open the next
        // one. Not spam moves it back to the inbox.
        function moveThread(to, text) {
            const t = threads[current]
            if (!t || folders[folder].dir === to) return
            // Only the messages in the folder being looked at: your own replies stay in Sent.
            const q = "thread:" + t.thread + " and (" + folders[folder].query + ")"
            const back = folders[folder].dir
            // In the inbox's folder a message shows in Inbox by its inbox tag; anywhere else it loses the tag.
            const inbox = dir => [dir === "INBOX" ? "+inbox" : "-inbox"]
            nm.move(to, q, r => {
                if (r.error) { say(r.error); return }
                const ids = (r.ids || []).map(i => "id:\"" + i + "\"").join(" or ")
                if (ids) done({ text: text, undo: () => nm.move(back, ids, () => nm.tag(inbox(back), ids, () => reload(false))) })
                nm.tag(inbox(to), to === "INBOX" && ids ? ids : "thread:" + t.thread, () => reload(false))
            })
        }
        function trash() { moveThread("Trash", "Moved to Trash") }
        function archive() { moveThread("Archive", "Archived") }
        // ! marks the thread as spam, or in Spam as not spam.
        function spam() {
            if (folders[folder].dir === "Spam") moveThread("INBOX", "Not spam: moved to Inbox")
            else moveThread("Spam", "Marked as spam")
        }

        // ⌘Z (Ctrl+Z) takes back archive, delete and spam, newest first.
        property var undoStack: []
        function done(step) { undoStack = undoStack.concat([step]).slice(-undoDepth); say(step.text + "   ⌘Z undoes") }
        function undo() {
            if (undoStack.length === 0) { say("Nothing to undo"); return }
            const step = undoStack[undoStack.length - 1]
            undoStack = undoStack.slice(0, -1)
            step.undo()
            say("Undone: " + step.text.toLowerCase())
        }

        // A quiet line under the list for what just happened.
        property string note: ""
        function say(t) { note = t; noteTimer.restart() }
        Timer { id: noteTimer; interval: 4000; onTriggered: win.note = "" }

        // Opens the thread of a message in the inbox (or wherever it is now, if it has left it), then calls then().
        function openMessage(id, then) {
            nm.run(["search", "--output=threads", "--exclude=false", "id:\"" + id + "\""], t => {
                const thread = t.trim().replace(/^thread:/, "")
                if (thread === "") { say("That message is gone"); return }
                folder = 0
                search.text = ""
                nm.search(query(), list => {
                    let i = list.findIndex(x => x.thread === thread)
                    if (i < 0) {
                        // Not in the inbox any more: its thread, searched for in the folder the message is in now (the
                        // inbox's folder without the inbox tag is Archive).
                        nm.run(["search", "--output=files", "--exclude=false", "id:\"" + id + "\""], files => {
                            const dir = (files.split("\n")[0].match(/([^\/]+)\/(cur|new)\/[^\/]+$/) || [])[1] || ""
                            const f = folders.findIndex((x, n) => n > 0 && x.dir === (dir === "INBOX" ? "Archive" : dir))
                            folder = f >= 0 ? f : folders.findIndex(x => x.name === "Archive")
                            search.text = "thread:" + thread
                            nm.search(query(), l2 => { threads = l2; open(l2.length ? 0 : -1, then) })
                        })
                        return
                    }
                    threads = list
                    open(i, then)
                })
                list.forceActiveFocus()
            })
        }

        function pickFolder(i) { folder = i; search.text = ""; reload(false); list.forceActiveFocus() }

        function when(ts) {
            const d = new Date(ts * 1000), now = new Date()
            if (d.toDateString() === now.toDateString()) return Qt.formatTime(d, "HH:mm")
            if (now - d < 6 * 86400000) return Qt.formatDate(d, "ddd")
            if (d.getFullYear() === now.getFullYear()) return Qt.formatDate(d, "d MMM")
            return Qt.formatDate(d, "d MMM yyyy")
        }
        function fullDate(ts) { return Qt.formatDateTime(new Date(ts * 1000), "ddd d MMM yyyy, HH:mm") }
        function name(from) { const m = from.match(/^\s*"?([^"<]*?)"?\s*</); return m && m[1] !== "" ? m[1] : from.replace(/[<>]/g, "") }
        function address(from) { const m = from.match(/<([^>]+)>/); return m ? m[1] : "" }
        // Plain text to rich text: links clickable, quoted lines quiet.
        function rich(t) {
            const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
            return t.replace(/\r/g, "").split("\n").map(l => {
                let h = esc(l).replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1" style="color:' + c.accent + '">$1</a>')
                return /^\s*&gt;/.test(h) ? '<span style="color:' + c.faint + '">' + h + '</span>' : h
            }).join("<br>")
        }

        Component.onCompleted: {
            reload(false); list.forceActiveFocus()
            nm.compose(["account"], r => { if (!r.error) account = r })
        }

        // Picks up what the mail sync brought in.
        Timer { interval: 30000; running: true; repeat: true; onTriggered: win.reload(true) }

        // Mac Mail's keys, with ⌘⇧C (Ctrl+Shift+C) for Claude's reply. Nightdrive sends ⌘Z ⌘R ⌘F to apps as Ctrl+…, which are also the PC mail apps' keys;
        // ⌘N, ⌘B and ⌘⇧C arrive as Super (Meta) + the key. ⌘⏎ opens a terminal, so sending stays Ctrl+⏎.
        Shortcut { sequences: ["/", "Ctrl+F"]; onActivated: search.forceActiveFocus() }
        Shortcut { sequences: ["Meta+Shift+C", "Ctrl+Shift+C"]; onActivated: win.compose("claude") }
        Shortcut { sequence: "Ctrl+R"; onActivated: win.reload(true) }
        Shortcut { sequences: ["Ctrl+N", "Meta+N"]; onActivated: win.compose("new") }
        Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
        Shortcut { sequences: ["Meta+,", "Ctrl+,"]; onActivated: win.showSettings = !win.showSettings }
        Shortcut { sequence: "Ctrl+Z"; onActivated: win.undo() }
        Shortcut { sequences: ["Ctrl+B", "Meta+B"]; onActivated: win.showFolders = !win.showFolders }

        RowLayout {
            anchors.fill: parent
            // Holding ⌘ (Super) shows the keys.
            Keys.onPressed: e => sheet.pressed(e)
            Keys.onReleased: e => sheet.released(e)
            spacing: 0

            // Folders
            Rectangle {
                Layout.preferredWidth: win.width < 900 ? 168 : 208
                visible: win.showFolders
                Layout.fillHeight: true
                color: "transparent"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 28
                    anchors.bottomMargin: 24
                    spacing: 0
                    // The title's line and the search's are as high (headerHeight) and as far from the top, so the first
                    // folder and the first message line up
                    Row {
                        Layout.leftMargin: 28
                        Layout.preferredHeight: win.headerHeight
                        Layout.bottomMargin: win.headerGap
                        spacing: 3
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Mail"; color: c.title; font.family: c.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Rectangle { width: 7; height: 14; color: c.primary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Repeater {
                        model: win.folders
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            implicitHeight: 34
                            radius: 8
                            color: index === win.folder ? c.sel : fh.hovered ? c.hover : "transparent"
                            HoverHandler { id: fh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.pickFolder(index) }
                            Text {
                                anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name; font.family: c.font; font.pixelSize: 13
                                color: index === win.folder ? c.title : c.dim
                            }
                            Text {
                                anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                                text: win.unreadCounts[index] > 0 ? win.unreadCounts[index] : ""
                                font.family: c.font; font.pixelSize: 11; color: c.dim
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Row {
                        Layout.leftMargin: 28
                        Layout.bottomMargin: 14
                        spacing: 8
                        KeyCap { anchors.verticalCenter: parent.verticalCenter; c: win.look; keys: "⌘,"; tint: win.look.faint }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Settings"; font.family: c.font; font.pixelSize: 12
                            color: sh.hovered ? c.text : c.dim
                            HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.showSettings = true }
                        }
                    }
                    Text {
                        Layout.leftMargin: 28
                        text: win.account.address; color: c.faint; font.family: c.font; font.pixelSize: 11
                    }
                }
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: c.line }
            }

            // Thread list
            Rectangle {
                Layout.preferredWidth: Math.max(280, Math.min(400, win.width * 0.3))
                Layout.fillHeight: true
                color: "transparent"
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.margins: 28
                        Layout.preferredHeight: win.headerHeight
                        Layout.bottomMargin: win.headerGap
                        spacing: 10
                        Text { text: "⌕"; color: c.faint; font.pixelSize: 15 }
                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            color: c.text; font.family: c.font; font.pixelSize: 13
                            selectionColor: c.sel
                            Text {
                                visible: !search.text && !search.activeFocus
                                text: "Search"; color: c.faint; font: search.font
                            }
                            onTextEdited: searchDelay.restart()
                            Keys.onEscapePressed: { text = ""; win.reload(false); list.forceActiveFocus() }
                            Keys.onReturnPressed: list.forceActiveFocus()
                            Keys.onDownPressed: list.forceActiveFocus()
                            Timer { id: searchDelay; interval: 150; onTriggered: win.reload(false) }
                        }
                        KeyCap { c: win.look; keys: "/"; tint: win.look.faint; visible: !search.activeFocus }
                    }
                    ListView {
                        id: list
                        Layout.fillWidth: true
                        // The view itself is inset: ListView places its delegates at x 0.
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        Layout.fillHeight: true
                        clip: true
                        model: win.threads
                        currentIndex: win.current
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 0
                        TouchScroll { view: list }
                        spacing: 2
                        bottomMargin: 12
                        focus: true
                        Keys.onPressed: e => {
                            const k = e.key
                            // The list takes most keys before they reach the sheet: any but ? closes it here.
                            if (win.cheats && k !== Qt.Key_Question) win.cheats = false
                            const ctrl = e.modifiers & Qt.ControlModifier
                            const alt = e.modifiers & Qt.AltModifier
                            if (ctrl && k === Qt.Key_Down && win.folder < win.folders.length - 1) win.pickFolder(win.folder + 1)
                            else if (ctrl && k === Qt.Key_Up && win.folder > 0) win.pickFolder(win.folder - 1)
                            else if (ctrl && (k === Qt.Key_Up || k === Qt.Key_Down)) {}
                            // ⌥ arrows (and j k) move in the list; plain arrows scroll the message.
                            else if ((k === Qt.Key_J || alt && k === Qt.Key_Down) && win.current < win.threads.length - 1) win.open(win.current + 1)
                            else if ((k === Qt.Key_K || alt && k === Qt.Key_Up) && win.current > 0) win.open(win.current - 1)
                            else if (alt && (k === Qt.Key_Up || k === Qt.Key_Down)) {}
                            else if (k === Qt.Key_Down) win.scrollMessage(win.arrowStep)
                            else if (k === Qt.Key_Up) win.scrollMessage(-win.arrowStep)
                            else if (k === Qt.Key_Question) win.cheats = !win.cheats
                            else if (k === Qt.Key_H) win.htmlMode = (win.htmlMode + 1) % 3
                            else if (k === Qt.Key_C) win.compose("new")
                            else if (k === Qt.Key_F) win.compose("forward")
                            else if (k === Qt.Key_Return || k === Qt.Key_Enter) { if (win.draft()) win.compose("resume"); else win.openWindow(win.current) }
                            // r answers everyone, ⇧R only the sender; ⌘⇧C (Ctrl+Shift+C) has Claude write the reply.
                            else if (k === Qt.Key_R && !alt) win.compose(e.modifiers & Qt.ShiftModifier ? "reply" : "all")
                            else if (k === Qt.Key_A || k === Qt.Key_E) win.archive()
                            else if (k === Qt.Key_D || k === Qt.Key_NumberSign) win.trash()
                            else if (k === Qt.Key_Exclam) win.spam()
                            else if (k === Qt.Key_U && win.threads[win.current]) nm.tag(["+unread"], "thread:" + win.threads[win.current].thread, () => win.reload(true))
                            else if (k >= Qt.Key_1 && k < Qt.Key_1 + win.folders.length) win.pickFolder(k - Qt.Key_1)
                            else if (k === Qt.Key_Space) win.scrollMessage((e.modifiers & Qt.ShiftModifier ? -1 : 1) * (reader.height - 80))
                            else return
                            e.accepted = true
                        }
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool unread: modelData.tags.indexOf("unread") >= 0
                            width: ListView.view.width
                            implicitHeight: col.implicitHeight + 36
                            radius: 8
                            color: index === win.current ? c.sel : th.hovered ? c.hover : "transparent"
                            HoverHandler { id: th; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: { win.open(row.index); list.forceActiveFocus() }
                                onDoubleTapped: if (win.draft()) win.compose("resume"); else win.openWindow(row.index)
                            }
                            Column {
                                id: col
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.leftMargin: 16; anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Item {
                                    width: parent.width; height: who.implicitHeight
                                    Text {
                                        id: who
                                        anchors.left: parent.left; anchors.right: date.left; anchors.rightMargin: 16
                                        elide: Text.ElideRight
                                        text: row.modelData.authors + (row.modelData.total > 1 ? "  " + row.modelData.total : "")
                                        font.family: c.font; font.pixelSize: 13
                                        font.weight: row.unread ? Font.Medium : Font.Normal
                                        color: c.title
                                    }
                                    // Unread: a dot in the row's left padding, in the accent of the cursor by the name.
                                    Rectangle {
                                        visible: row.unread
                                        width: 6; height: 6; radius: 3
                                        x: -11; anchors.verticalCenter: who.verticalCenter
                                        color: c.primary
                                    }
                                    Text {
                                        id: date
                                        anchors.right: parent.right; anchors.baseline: who.baseline
                                        text: win.when(row.modelData.timestamp)
                                        font.family: c.font; font.pixelSize: 11; color: row.unread ? c.title : c.faint
                                    }
                                }
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: row.modelData.subject || "(no subject)"
                                    font.family: c.font; font.pixelSize: 12
                                    color: row.unread ? c.title : c.dim
                                }
                            }
                        }
                        Text {
                            visible: win.threads.length === 0
                            anchors.centerIn: parent
                            text: "Nothing here"; color: c.faint; font.family: c.font; font.pixelSize: 12
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.margins: 28
                        Layout.topMargin: 8
                        visible: win.note !== ""
                        elide: Text.ElideRight
                        text: win.note; color: c.dim; font.family: c.font; font.pixelSize: 11
                    }
                }
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: c.line }
            }

            // The open thread
            Thread {
                id: reader
                Layout.fillWidth: true
                Layout.fillHeight: true
                app: win; c: app.look; nm: app.mailer
                messages: win.messages
                htmlMode: win.htmlMode
                onCycleHtml: win.htmlMode = (win.htmlMode + 1) % 3
                onResumeDraft: win.compose("resume")
            }
        }

        // Settings: one row per choice; ←/→ or a click changes it, Esc or ⌘, closes.
        property bool showSettings: false
        onShowSettingsChanged: if (showSettings) settingsPanel.forceActiveFocus(); else list.forceActiveFocus()
        readonly property var settingRows: [
            { key: "composeFloats", title: "New windows", choices: [[true, "Floating"], [false, "In the grid"]],
              hint: "Where writing and message windows open" },
            { key: "view", title: "Messages open as", choices: [[0, "Text"], [1, "HTML, dark"], [2, "HTML as sent"]],
              hint: "How a message shows first, when it has HTML (h changes it)" },
            { key: "claudeReads", title: "Claude reads", choices: [["thread", "The whole thread"], ["selection", "Only what I select"]],
              hint: "What is sent to Claude when it writes a reply (⌘⇧C)" }
        ]
        Rectangle {
            id: settingsPanel
            anchors.fill: parent
            visible: win.showSettings
            color: c.scrim
            property int row: 0
            TapHandler { onTapped: win.showSettings = false }
            Keys.onPressed: e => {
                const r = win.settingRows[row]
                const i = r.choices.findIndex(ch => ch[0] === win.settings[r.key])
                if (e.key === Qt.Key_Escape) win.showSettings = false
                else if (e.key === Qt.Key_Down) row = Math.min(row + 1, win.settingRows.length - 1)
                else if (e.key === Qt.Key_Up) row = Math.max(row - 1, 0)
                else if (e.key === Qt.Key_Left && i > 0) win.setting(r.key, r.choices[i - 1][0])
                else if (e.key === Qt.Key_Right && i < r.choices.length - 1) win.setting(r.key, r.choices[i + 1][0])
                else return
                e.accepted = true
            }
            Rectangle {
                anchors.centerIn: parent
                width: 560
                height: settingsCol.implicitHeight + 72
                radius: 14
                color: c.solid
                border.color: c.line
                TapHandler {}       // a click inside keeps it open
                Column {
                    id: settingsCol
                    x: 40; y: 36
                    width: parent.width - 80
                    spacing: 28
                    Row {
                        width: parent.width
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Settings"; color: c.title; font.family: c.font; font.pixelSize: 15; font.weight: Font.Medium; width: parent.width - escHint.width }
                        KeyCap { id: escHint; anchors.verticalCenter: parent.verticalCenter; c: win.look; keys: "esc"; tint: win.look.faint }
                    }
                    Repeater {
                        model: win.settingRows
                        delegate: Column {
                            id: settingRow
                            required property var modelData
                            required property int index
                            width: settingsCol.width
                            spacing: 10
                            Text { text: modelData.title; color: index === settingsPanel.row ? c.title : c.text; font.family: c.font; font.pixelSize: 13 }
                            Row {
                                spacing: 8
                                Repeater {
                                    model: settingRow.modelData.choices
                                    delegate: Rectangle {
                                        id: choice
                                        required property var modelData
                                        readonly property bool on: win.settings[settingRow.modelData.key] === modelData[0]
                                        implicitWidth: choiceText.implicitWidth + 32
                                        implicitHeight: 34
                                        radius: 8
                                        color: on ? c.sel : chh.hovered ? c.hover : "transparent"
                                        border.color: on ? c.primary : c.line
                                        HoverHandler { id: chh; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: { settingsPanel.row = settingRow.index; win.setting(settingRow.modelData.key, choice.modelData[0]) } }
                                        Text { id: choiceText; anchors.centerIn: parent; text: choice.modelData[1]; color: choice.on ? c.title : c.dim; font.family: c.font; font.pixelSize: 12 }
                                    }
                                }
                            }
                            Row {
                                spacing: 8
                                KeyCap { anchors.verticalCenter: parent.verticalCenter; c: win.look; keys: "←  →"; tint: win.look.faint }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: settingRow.modelData.hint; color: c.faint; font.family: c.font; font.pixelSize: 11 }
                            }
                        }
                    }
                }
            }
        }

        property alias cheats: sheet.shown

        readonly property var keyHelp: [
            { title: "Read", keys: [["⌥↑ ⌥↓  j k", "Previous, next"], ["⏎", "Open in a window"], ["↑ ↓", "Scroll the message"], ["Space  ⇧Space", "Page down, up"], ["h", "HTML or text"],
                                    ["⌘F  /", "Search"], ["Esc", "Clear the search"]] },
            { title: "Act", keys: [["a", "Archive"], ["d", "Move to Trash"], ["!", "Spam (in Spam: not spam)"], ["⌘Z", "Undo"], ["u", "Mark unread"], ["⌘R", "Refresh"]] },
            { title: "Write", keys: [["⌘N  c", "New message"], ["r", "Reply to all"], ["⇧R", "Reply to the sender only"], ["f", "Forward"],
                                     ["⏎", "Continue a draft (in Drafts)"], ["⌘⇧C", "Claude writes the reply"], ["⌘⇧C", "…from the selected text"],
                                     ["⌘⇧A", "Attach files"], ["Ctrl ⏎", "Send"], ["⌘S", "Save in Drafts"], ["Esc", "Close (Esc Esc: throw away)"]] },
            { title: "Folders", keys: [["Ctrl ↑ ↓", "Previous, next"], ["1 – 6", "Go to a folder"], ["⌘B", "Hide or show"], ["⌘,", "Settings"]] }
        ]

        KeySheet { id: sheet; c: win.look; groups: win.keyHelp }
    }

    // Writing opens in a window of its own. To float (the default), its size is fixed while it opens, which tiling
    // compositors (Hyprland, Sway) take as a dialog and float; then it is freed so the window can be resized. Set to open
    // in the grid, its size is free from the start and the compositor tiles it.
    FloatingWindow {
        id: composeWin
        property bool done: false
        property bool opening: false
        onOpeningChanged: if (opening && !win.settings.composeFloats) opening = false
        visible: false
        minimumSize: opening ? Qt.size(implicitWidth, implicitHeight) : Qt.size(360, 400)
        maximumSize: opening ? Qt.size(implicitWidth, implicitHeight) : Qt.size(0, 0)
        Timer { id: release; interval: 400; onTriggered: composeWin.opening = false }
        title: composer.heading
        implicitWidth: 760
        implicitHeight: 720
        color: c.bg
        onVisibleChanged: {
            if (visible) { done = false; release.restart() }
            // Closed by the compositor (⌘W): nothing written is lost, so anything written goes to Drafts.
            else if (!done && (composer.draftId !== "" || !composer.untouched())) win.saveDraft(composer.fields(), true)
        }
        Compose {
            id: composer
            anchors.fill: parent
            c: c
            onSend: f => win.sendMail(f)
            onSuggest: (request, x, y) => win.suggest(request, x, y)
            claudeReads: win.settings.claudeReads || ""
            onChooseReads: v => win.setting("claudeReads", v)
            onSave: (f, close) => win.saveDraft(f, close)
            onDismiss: win.dismissCompose()
            onPickFiles: nm.pick(paths => composer.attach(paths))
        }
    }

    // A message window: the thread, with the reading keys and replies of its own. Esc or ⌘W closes it.
    Component {
        id: messageWindow
        FloatingWindow {
            id: mw
            property var msgs: []
            property int htmlMode: win.settings.view
            property bool opening: win.settings.composeFloats
            title: msgs.length ? msgs[0].subject || "(no subject)" : "Message"
            implicitWidth: 820
            implicitHeight: 900
            minimumSize: opening ? Qt.size(implicitWidth, implicitHeight) : Qt.size(360, 300)
            maximumSize: opening ? Qt.size(implicitWidth, implicitHeight) : Qt.size(0, 0)
            Timer { running: true; interval: 400; onTriggered: mw.opening = false }
            color: c.bg
            visible: true
            onClosed: destroy()
            function scroll(dy) { thread.cancelFlick(); thread.contentY = Math.max(0, Math.min(thread.contentHeight - thread.height, thread.contentY + dy)) }

            Thread {
                id: thread
                anchors.fill: parent
                app: win; c: app.look; nm: app.mailer
                messages: mw.msgs
                htmlMode: mw.htmlMode
                onCycleHtml: mw.htmlMode = (mw.htmlMode + 1) % 3
                onResumeDraft: win.compose("resume", mw.msgs)
                focus: true
                Keys.onReleased: e => keys.released(e)
                Keys.onPressed: e => {
                    const k = e.key
                    keys.pressed(e)
                    if (k === Qt.Key_Question) keys.shown = !keys.shown
                    else if (k === Qt.Key_Escape) mw.visible = false
                    else if (k === Qt.Key_Down) mw.scroll(win.arrowStep)
                    else if (k === Qt.Key_Up) mw.scroll(-win.arrowStep)
                    else if (k === Qt.Key_Space) mw.scroll((e.modifiers & Qt.ShiftModifier ? -1 : 1) * (thread.height - 80))
                    else if (k === Qt.Key_H) mw.htmlMode = (mw.htmlMode + 1) % 3
                    else if (k === Qt.Key_R) win.compose(e.modifiers & Qt.ShiftModifier ? "reply" : "all", mw.msgs)
                    else if (k === Qt.Key_F) win.compose("forward", mw.msgs)
                    else return
                    e.accepted = true
                }
            }
            Shortcut { sequences: ["Meta+Shift+C", "Ctrl+Shift+C"]; onActivated: win.compose("claude", mw.msgs) }
            KeySheet {
                id: keys
                c: win.look
                groups: [
                    { title: "Read", keys: [["↑ ↓", "Scroll"], ["Space  ⇧Space", "Page down, up"], ["h", "HTML or text"], ["Esc  ⌘W", "Close the window"]] },
                    { title: "Write", keys: [["r", "Reply to all"], ["⇧R", "Reply to the sender only"], ["f", "Forward"], ["⌘⇧C", "Claude writes the reply"]] }
                ]
            }
            onVisibleChanged: if (!visible) destroy()
        }
    }
}
