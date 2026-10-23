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
            readonly property color divider: Qt.lighter(line, 1.2)     // the lines between the panes
            // Under the pointer: the selected row's colour, fainter, so a row you point at never looks picked
            readonly property color hover: Qt.rgba(sel.r, sel.g, sel.b, 0.5)
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
            // Settings › Apps › Mail (`nightmail settings`)
            function openSettings(): void { win.showSettings = true }
            // A mailto: link (`nightmail mailto:…`, when Mail is the email app: launcher › Settings › Apps › Default apps)
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

        // @NAME in a query is the account's folder NAME (folderQuery)
        readonly property var folders: [
            { name: "Inbox", dir: "INBOX", glyph: "inbox", query: "@INBOX and tag:inbox" },
            { name: "Sent", dir: "Sent", glyph: "send", query: "@Sent" },
            { name: "Drafts", dir: "Drafts", glyph: "file-pen", query: "@Drafts" },
            // Archived before archive moved mail to the Archive folder: in the inbox's folder without the inbox tag. Gmail's
            // Archive (All Mail) holds the inbox's messages too, and Trash and Spam lose theirs only at the next sync.
            { name: "Archive", dir: "Archive", glyph: "archive", query: "(@Archive and not @INBOX and not @Trash and not @Spam) or (@INBOX and not tag:inbox)" },
            { name: "Spam", dir: "Spam", glyph: "ban", query: "@Spam" },
            { name: "Trash", dir: "Trash", glyph: "trash-2", query: "@Trash" }
        ]
        readonly property int arrowStep: 80     // px an arrow key scrolls the message
        readonly property int headerHeight: 22  // the folders' title line and the list's search line
        readonly property int headerGap: 30     // from them to the first folder and the first message
        readonly property int undoDepth: 20     // steps ⌘Z can take back
        property int folder: 0
        property bool showFolders: true
        property int htmlMode: 0            // h cycles: 0 text, 1 HTML on the dark page, 2 HTML on light paper; each thread opens in settings.view
        // The accounts (compose.py accounts: { id, name, address, maildir, signature }), each with its own folders: Mail
        // shows one at a time, its mail being what lies under its folder in ~/Mail. Tab changes it.
        property var accounts: []
        property int acct: 0
        readonly property var account: accounts[acct] || { id: "", address: "", maildir: "", signature: "" }
        property var inboxUnread: ({})      // unread threads in each account's inbox, by id
        function pickAccount(i) {
            if (i === acct || i < 0 || i >= accounts.length) return
            acct = i
            setting("account", accounts[i].id)
            pickFolder(0)
        }
        // A folder's query in the account shown (or another one). The account and the folder are one path term: notmuch
        // matches each term against any of a message's files, so "path:account/** and folder:INBOX" would also take a
        // message mailed between two of your accounts, from the other one's inbox.
        function folderQuery(i, a) {
            return "(" + folders[i].query.replace(/@(\w+)/g, (m, d) => folderTerm(d, a)) + ")"
        }
        function folderTerm(dir, a) {
            const m = (a || account).maildir
            return m ? "path:\"" + m + "/" + dir + "/**\"" : "folder:/" + dir + "$/"
        }
        // Where the files of the folder being looked at are, for move.py and erase.py: only those move
        function sources(i) {
            const m = account.maildir, d = folders[i].dir
            return (d === "Archive" ? ["Archive", "INBOX"] : [d]).map(x => m ? m + "/" + x : x)
        }
        property var threads: []
        property int current: -1
        property var messages: []
        property var unreadCounts: ({})

        function query() {
            const q = search.text.trim()
            return q === "" ? folderQuery(folder) : "(" + folderQuery(folder) + ") and (" + q + ")"
        }

        // keep: the open thread stays open; at: where to open one when it has gone (the one after a moved thread)
        function reload(keep, at) {
            const id = keep && current >= 0 && threads[current] ? threads[current].thread : ""
            nm.search(query(), list => {
                threads = list
                let i = list.findIndex(t => t.thread === id)
                if (i < 0) i = list.length > 0 ? Math.min(at || 0, list.length - 1) : -1
                // Threads picked stay picked through the sync's reload, and nothing opens (it would mark one read)
                if (keep && picked.length) {
                    picked = picked.filter(p => list.some(t => t.thread === p))
                    if (picked.length > 1) { current = i; return }
                    open(i); return
                }
                if (!keep || i !== current) open(i)
            })
            for (let f = 0; f < folders.length; f++) {
                const n = f
                nm.run(["count", "--output=threads", "(" + folderQuery(f) + ") and tag:unread"], t => {
                    const u = Object.assign({}, unreadCounts); u[n] = parseInt(t) || 0; unreadCounts = u
                })
            }
            for (const a of accounts) {
                nm.run(["count", "--output=threads", "(" + folderQuery(0, a) + ") and tag:unread"], t => {
                    const u = Object.assign({}, inboxUnread); u[a.id] = parseInt(t) || 0; inboxUnread = u
                })
            }
        }

        // again: the second try, after the list was read anew
        function open(i, then, again) {
            current = i
            picked = []; anchorId = ""
            htmlMode = settings.view
            if (i < 0) { messages = []; return }
            const t = threads[i]
            // By id: marking it read reloads the list (new objects) before a long thread has come back
            nm.show(t.thread, m => {
                if (!threads[current] || threads[current].thread !== t.thread) return
                // Nothing in it: indexing a sync has joined the thread to another one under a new id since the list was
                // read. The list is read again, and the thread with the same subject and date opens.
                if (m.length === 0 && !again) {
                    nm.search(query(), list => {
                        threads = list
                        const j = list.findIndex(x => x.subject === t.subject && x.timestamp === t.timestamp)
                        open(j >= 0 ? j : Math.min(i, list.length - 1), then, true)
                    })
                    return
                }
                messages = m
                if (then) then()
            })
            if (t.tags.indexOf("unread") >= 0)
                nm.tag(["-unread"], "thread:" + t.thread, () => reload(true))
        }

        // Writing: mode "new", "reply" (to the sender), "all", "claude" (a reply Claude drafts) or "forward", all on the
        // thread's last message, or "resume" to write on the thread's draft. The thread is the open one, or msgs (a
        // message window's).
        function compose(mode, msgs, fields) {
            const all = msgs || messages
            if (composeWin.visible) return
            if (mode === "new") {
                // From the account shown, with its signature under the text
                const f = Object.assign({}, fields || {}, { account: account.id })
                if (account.signature) f.body = (f.body || "") + "\n\n" + account.signature
                composer.start("New message", f); showCompose(); return
            }
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
            nm.addresses(list => composer.book = list.filter(a => !accounts.some(x => x.address === a.address)))
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
        function saveAll(msg) {
            nm.saveAll(msg.id, msg.files, r => {
                if (r.error) { say(r.error); return }
                const dir = r.paths.length ? r.paths[0].replace(/\/[^\/]*$/, "").replace(Quickshell.env("HOME"), "~") : ""
                say("Saved " + r.paths.length + " attachments to " + dir)
            })
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

        // Several threads picked (⇧-click, Ctrl-click, ⇧↑ ⇧↓, ⌘A): archive, delete, spam, u and a drag act on them all,
        // and the reading pane says how many. Without any, they act on the open thread. current is then where the
        // keyboard is, and the open thread's messages stay as they were (opening one would mark it read).
        property var picked: []             // the picked threads' ids; empty: only the open thread
        property string anchorId: ""        // the thread a ⇧ range starts from
        function isPicked(t) { return picked.indexOf(t.thread) >= 0 }
        function targets() { return picked.length ? threads.filter(isPicked) : threads[current] ? [threads[current]] : [] }
        function pickRange(i) {
            if (i < 0 || i >= threads.length) return
            let a = threads.findIndex(t => t.thread === anchorId)
            if (a < 0) a = current
            if (a === i) { open(i); return }
            picked = threads.slice(Math.min(a, i), Math.max(a, i) + 1).map(t => t.thread)
            anchorId = threads[a].thread
            current = i
        }
        function togglePick(i) {
            const id = threads[i].thread
            const base = picked.length ? picked : threads[current] ? [threads[current].thread] : []
            const next = base.indexOf(id) >= 0 ? base.filter(p => p !== id) : base.concat([id])
            if (next.length <= 1) { open(next.length ? threads.findIndex(t => t.thread === next[0]) : i); return }
            picked = next; anchorId = id; current = i
        }
        function pickAll() {
            if (threads.length < 2) return
            picked = threads.map(t => t.thread); anchorId = threads[0].thread
        }

        // Delete, archive and spam move the open thread (or the picked ones) to the account's Trash, Archive or Spam
        // folder (on the server too, at the next sync, so a phone sees it the same way and the server's spam filter
        // learns from it) and open the next one. Not spam moves it back to the inbox.
        function moveThread(to, text, which) {
            const ts = which || targets()
            if (!ts.length || folders[folder].dir === to) return
            // Other threads than the open one (dragged to a folder): the open one stays open
            const openId = threads[current] ? threads[current].thread : ""
            const keep = !ts.some(t => t.thread === openId)
            const at = Math.min.apply(null, ts.map(t => threads.findIndex(x => x.thread === t.thread)))
            if (ts.length > 1) text += ": " + ts.length + " threads"
            const tq = ts.map(t => "thread:" + t.thread).join(" or ")
            // Only the messages in the folder being looked at: your own replies stay in Sent.
            const q = "(" + tq + ") and (" + folderQuery(folder) + ")"
            const back = folders[folder].dir
            // In the inbox's folder a message shows in Inbox by its inbox tag; anywhere else it loses the tag.
            const inbox = dir => [dir === "INBOX" ? "+inbox" : "-inbox"]
            const from = sources(folder), there = [account.maildir ? account.maildir + "/" + to : to]
            nm.move(to, q, from, r => {
                if (r.error) { say(r.error); return }
                const ids = (r.ids || []).map(i => "id:\"" + i + "\"").join(" or ")
                if (ids) done({ text: text, undo: () => nm.move(back, ids, there, () => nm.tag(inbox(back), ids, () => reload(keep))) })
                nm.tag(inbox(to), to === "INBOX" && ids ? ids : tq, () => reload(keep, at))
            })
        }
        // d: to Trash, and in Trash deleted for good (after asking)
        function trash() { if (folders[folder].dir === "Trash") eraseThreads(); else moveThread("Trash", "Moved to Trash") }

        // Deleting for good, in Trash: the files go, and the next sync deletes them on the server. There is no ⌘Z, so it
        // asks first (the confirm panel: Enter deletes, Esc doesn't).
        property var confirm: null          // { title, detail, action, run }
        onConfirmChanged: if (confirm) confirmPanel.forceActiveFocus(); else list.forceActiveFocus()
        function erase(query, n) {
            nm.erase(query, sources(folders.findIndex(f => f.dir === "Trash")), r => {
                if (r.error) { say(r.error); return }
                say(r.erased ? "Deleted for good: " + n + (n === 1 ? " thread" : " threads") : "Nothing deleted")
                reload(false, current)
            })
        }
        function eraseThreads() {
            const ts = targets()
            if (!ts.length) return
            const n = ts.length
            const q = "(" + ts.map(t => "thread:" + t.thread).join(" or ") + ") and (" + folderQuery(folder) + ")"
            confirm = { title: n === 1 ? "Delete this thread for good?" : "Delete " + n + " threads for good?",
                        detail: (n === 1 ? "It is" : "They are") + " deleted here and, at the next sync, on the server. This can't be undone.",
                        action: "Delete", run: () => erase(q, n) }
        }
        function emptyTrash() {
            const t = folders.findIndex(f => f.dir === "Trash"), q = folderQuery(t)
            nm.run(["count", "--output=threads", "--exclude=false", q], out => {
                const n = parseInt(out) || 0
                if (!n) { say("Trash is empty"); return }
                confirm = { title: "Empty Trash?", detail: (n === 1 ? "The thread" : "All " + n + " threads") + " in Trash (" + account.address
                                + (n === 1 ? ") is" : ") are") + " deleted here and, at the next sync, on the server. This can't be undone.",
                            action: "Empty Trash", run: () => erase(q, n) }
            })
        }
        // u: read threads (or a mix) become unread, and unread ones read
        function toggleRead() {
            const ts = targets()
            if (!ts.length) return
            const read = ts.every(t => t.tags.indexOf("unread") >= 0)
            nm.tag([read ? "-unread" : "+unread"], ts.map(t => "thread:" + t.thread).join(" or "), () => reload(true))
        }

        // ⇧U, or ✓ on a folder: every unread message in it read (with a search on, the results only), in the next sync on
        // the server too. ⌘Z makes the same ones unread again: they carry a tag of their own until then (undoTag), so the
        // step doesn't keep thousands of ids.
        readonly property string undoTag: "nightmail-read-"
        function markAllRead(i) {
            const q = "(" + (i === folder ? query() : folderQuery(i)) + ") and tag:unread"
            nm.run(["count", "--output=threads", q], t => {
                const n = parseInt(t) || 0
                if (!n) { say("Nothing unread here"); return }
                const mark = undoTag + Date.now()
                nm.tag(["-unread", "+" + mark], q, () => {
                    done({ text: "Marked " + n + (n === 1 ? " thread" : " threads") + " read",
                           undo: () => nm.tag(["+unread", "-" + mark], "tag:" + mark, () => reload(true)) })
                    reload(true)
                })
            })
        }

        // Threads dragged from the list onto a folder move there, as the keys move them (⌘Z too). Inbox, Archive, Spam
        // and Trash take them; Sent and Drafts hold what you wrote, and the folder being looked at is where they are.
        property var dragged: null          // the threads being dragged (a picked one drags all the picked)
        property int dropFolder: -1         // the folder under it, if it takes it
        function takesDrop(i) { return ["INBOX", "Archive", "Spam", "Trash"].indexOf(folders[i].dir) >= 0 && i !== folder }
        function dragOver(pos) {
            ghost.x = pos.x + 12; ghost.y = pos.y - ghost.height / 2
            dropFolder = -1
            for (let i = 0; i < folders.length; i++) {
                const f = folderRows.itemAt(i)
                if (f && takesDrop(i) && f.contains(f.mapFromItem(null, pos.x, pos.y))) dropFolder = i
            }
        }
        function startDrag(t) { dragged = isPicked(t) ? targets() : [t] }
        function drop() {
            const t = dragged, i = dropFolder
            dragged = null; dropFolder = -1
            if (!t || i < 0) return
            const to = folders[i].dir
            moveThread(to, to === "Trash" ? "Moved to Trash" : to === "Archive" ? "Archived" : to === "Spam" ? "Marked as spam"
                           : folders[folder].dir === "Spam" ? "Not spam: moved to Inbox" : "Moved to Inbox", t)
        }
        function archive() { moveThread("Archive", "Archived") }
        // The reading pane's buttons, for the mouse: what the keys do (a archive, d delete, ! spam, r reply …)
        readonly property var readerActions: {
            const dir = folders[folder].dir
            return [{ id: "reply", icon: "reply", text: "Reply", tip: "Reply to all", keys: "r" },
                    { id: "claude", icon: "sparkles", text: "Reply with Claude", short: "Claude", tip: "Claude writes the reply", keys: "⌘⇧C" },
                    { id: "forward", icon: "forward", text: "Forward", tip: "Forward with the attachments", keys: "f" }]
                .concat(dir === "Archive" ? [] : [{ id: "archive", icon: "archive", text: "Archive", tip: "Archive", keys: "a" }])
                .concat([{ id: "trash", icon: "trash-2", text: dir === "Trash" ? "Delete for good" : "Delete", short: "Delete",
                           tip: dir === "Trash" ? "Delete for good (asks first)" : "Move to Trash", keys: "d" },
                         { id: "spam", icon: dir === "Spam" ? "inbox" : "ban", text: dir === "Spam" ? "Not spam" : "Spam",
                           tip: dir === "Spam" ? "Not spam: back to the Inbox" : "Mark as spam", keys: "!" }])
        }
        readonly property var windowActions: readerActions.slice(0, 3)
        function act(id, msgs) {
            if (id === "reply") compose("all", msgs)
            else if (id === "claude") compose("claude", msgs)
            else if (id === "forward") compose("forward", msgs)
            else if (id === "archive") archive()
            else if (id === "trash") trash()
            else if (id === "spam") spam()
            else if (id === "unread") toggleRead()
            else if (id === "single") open(current)
        }
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
            const q = "id:\"" + id + "\""
            nm.run(["search", "--output=files", "--exclude=false", q], files => {
                // …/<account>/<folder>/cur/<file>: the account shown becomes the message's (the one whose inbox has it,
                // when it was mailed between two of your accounts)
                const list = files.split("\n").filter(f => f !== "")
                const m = (list.find(f => /\/INBOX\/(cur|new)\//.test(f)) || list[0] || "").match(/([^\/]+)\/([^\/]+)\/(cur|new)\/[^\/]+$/)
                if (!m) { say("That message is gone"); return }
                const a = accounts.findIndex(x => x.maildir === m[1])
                if (a >= 0 && a !== acct) { acct = a; setting("account", accounts[a].id) }
                nm.run(["search", "--output=threads", "--exclude=false", q], t => {
                    const thread = t.trim().replace(/^thread:/, "")
                    folder = 0
                    search.text = ""
                    nm.search(query(), list => {
                        let i = list.findIndex(x => x.thread === thread)
                        if (i < 0) {
                            // Not in the inbox any more: its thread, searched for in the folder the message is in now
                            // (the inbox's folder without the inbox tag is Archive).
                            const f = folders.findIndex((x, n) => n > 0 && x.dir === (m[2] === "INBOX" ? "Archive" : m[2]))
                            folder = f >= 0 ? f : folders.findIndex(x => x.name === "Archive")
                            search.text = "thread:" + thread
                            nm.search(query(), l2 => { threads = l2; open(l2.length ? 0 : -1, then) })
                            return
                        }
                        threads = list
                        open(i, then)
                    })
                    list.forceActiveFocus()
                })
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
            // Marks of mark-all-read steps that can't be undone any more (the last run's)
            nm.run(["search", "--output=tags", "tag:/^" + undoTag + "/"], t => {
                const old = t.split("\n").filter(x => x.indexOf(undoTag) === 0)
                if (old.length) nm.tag(old.map(x => "-" + x), old.map(x => "tag:" + x).join(" or "))
            })
            loadAccounts()
            list.forceActiveFocus()
        }
        // Without an account yet (no account.conf), Mail offers to set one up (setupPanel), and looks again with each
        // round of the timer below, so the inbox shows once the setup has written it.
        property bool needsAccount: false
        function loadAccounts() {
            nm.compose(["accounts"], r => {
                if (r.error) { needsAccount = true; reload(false); return }
                needsAccount = false
                accounts = r.accounts
                acct = Math.max(0, accounts.findIndex(a => a.id === settings.account))
                reload(false)
            })
        }
        onNeedsAccountChanged: if (needsAccount) setupPanel.forceActiveFocus(); else list.forceActiveFocus()

        // Picks up what the mail sync brought in.
        Timer { interval: 30000; running: true; repeat: true; onTriggered: win.needsAccount ? win.loadAccounts() : win.reload(true) }

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
            // ? and Ctrl+? show the keys (KeySheet.qml)
            Keys.onPressed: e => sheet.pressed(e)
            spacing: 0

            // Folders
            Rectangle {
                Layout.preferredWidth: win.width < 900 ? 168 : 208
                z: 1        // a folder's tip lies over the list
                visible: win.showFolders
                Layout.fillHeight: true
                color: "transparent"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 18
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
                        id: folderRows
                        model: win.folders
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            implicitHeight: 34
                            radius: 8
                            color: index === win.folder ? c.sel : fh.hovered || index === win.dropFolder ? c.hover : "transparent"
                            border.color: index === win.dropFolder ? c.primary : "transparent"
                            HoverHandler { id: fh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.pickFolder(index) }
                            // The same glyphs as the reading pane's buttons, and the same look as Deck's sections
                            Text {
                                id: folderGlyph
                                anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                                text: Icons.g(modelData.glyph); font.family: Icons.family; font.pixelSize: 15
                                color: index === win.folder ? c.accent : c.dim
                            }
                            Text {
                                anchors.left: folderGlyph.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name; font.family: c.font; font.pixelSize: 13
                                color: index === win.folder ? c.title : c.dim
                            }
                            Text {
                                anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                                visible: !readButton.visible
                                text: win.unreadCounts[index] > 0 ? win.unreadCounts[index] : ""
                                font.family: c.font; font.pixelSize: 11; color: c.dim
                            }
                            // Under the pointer, the unread count gives way to ✓: mark all read
                            Rectangle {
                                id: readButton
                                visible: fh.hovered && win.unreadCounts[index] > 0
                                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                width: 26; height: 26; radius: 6
                                color: rh.hovered ? c.sel : "transparent"
                                HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: { win.markAllRead(index); list.forceActiveFocus() } }
                                Text { anchors.centerIn: parent; text: Icons.g("check-check"); font.family: Icons.family; font.pixelSize: 14; color: rh.hovered ? c.text : c.dim }
                                Tip { x: parent.width + 8; anchors.verticalCenter: parent.verticalCenter; c: win.look; text: "Mark all read"; keys: "⇧U"; hovered: rh.hovered }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    // More than one account: each with its inbox's unread count; a click or Tab shows another one's folders
                    Repeater {
                        model: win.accounts.length > 1 ? win.accounts : []
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            implicitHeight: 30
                            radius: 8
                            color: ah.hovered ? c.hover : "transparent"
                            HoverHandler { id: ah; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: { win.pickAccount(index); list.forceActiveFocus() } }
                            Rectangle {
                                visible: index === win.acct
                                x: 6; anchors.verticalCenter: parent.verticalCenter
                                width: 3; height: 14; radius: 1.5; color: c.primary
                            }
                            Text {
                                anchors.left: parent.left; anchors.leftMargin: 16; anchors.right: count.left; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: modelData.address; font.family: c.font; font.pixelSize: 12
                                color: index === win.acct ? c.title : c.dim
                            }
                            Text {
                                id: count
                                anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                                text: win.inboxUnread[modelData.id] > 0 ? win.inboxUnread[modelData.id] : ""
                                font.family: c.font; font.pixelSize: 11; color: c.dim
                            }
                        }
                    }
                    // The foot: Settings (its key in the tip) and the account, when there is only one
                    Item {
                        Layout.fillWidth: true
                        Layout.topMargin: win.accounts.length > 1 ? 12 : 0
                        implicitHeight: 26
                        // Its glyph lines up with the folders' names above
                        Rectangle {
                            id: gear
                            anchors.left: parent.left; anchors.leftMargin: 22; anchors.verticalCenter: parent.verticalCenter
                            width: 26; height: 26; radius: 6
                            color: sh.hovered ? c.hover : "transparent"
                            Text { anchors.centerIn: parent; text: Icons.g("settings"); font.family: Icons.family; font.pixelSize: 14; color: sh.hovered ? c.text : c.faint }
                            HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.showSettings = true }
                            Tip { anchors.bottom: parent.top; anchors.bottomMargin: 8; anchors.left: parent.left; c: win.look; text: "Settings"; keys: "⌘,"; hovered: sh.hovered }
                        }
                        Text {
                            anchors.left: gear.right; anchors.leftMargin: 4; anchors.right: parent.right; anchors.rightMargin: 28
                            anchors.verticalCenter: parent.verticalCenter
                            visible: win.accounts.length < 2
                            elide: Text.ElideRight
                            text: win.account.address; color: c.faint; font.family: c.font; font.pixelSize: 11
                        }
                    }
                }
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: c.divider }
            }

            // Thread list
            Rectangle {
                Layout.preferredWidth: Math.max(250, Math.min(370, win.width * 0.3 - 30))
                Layout.fillHeight: true
                color: "transparent"
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.margins: 28
                        Layout.topMargin: 18
                        Layout.preferredHeight: win.headerHeight
                        Layout.bottomMargin: win.headerGap
                        spacing: 10
                        // Held to the line's height, so the bigger glyph doesn't push the list down
                        Text { text: "⌕"; color: c.faint; font.pixelSize: 26; Layout.preferredHeight: win.headerHeight; verticalAlignment: Text.AlignVCenter; topPadding: -2 }
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
                            if (win.cheats && k !== Qt.Key_Question && sheet.modifierKeys.indexOf(k) < 0) win.cheats = false
                            const ctrl = e.modifiers & Qt.ControlModifier
                            const alt = e.modifiers & Qt.AltModifier
                            const shift = e.modifiers & Qt.ShiftModifier
                            // ⇧↑ ⇧↓ (⇧K ⇧J) pick threads from the open one on; ⌘A (Ctrl+A) picks them all, Esc none
                            if (shift && (k === Qt.Key_Down || k === Qt.Key_J)) win.pickRange(win.current + 1)
                            else if (shift && (k === Qt.Key_Up || k === Qt.Key_K)) win.pickRange(win.current - 1)
                            else if ((ctrl || e.modifiers & Qt.MetaModifier) && k === Qt.Key_A) win.pickAll()
                            else if (k === Qt.Key_Escape && win.picked.length) win.open(win.current)
                            // Tab and ⇧Tab show the next and previous account's folders
                            else if (k === Qt.Key_Tab && win.accounts.length > 1) win.pickAccount((win.acct + 1) % win.accounts.length)
                            else if (k === Qt.Key_Backtab && win.accounts.length > 1) win.pickAccount((win.acct + win.accounts.length - 1) % win.accounts.length)
                            else if (ctrl && k === Qt.Key_Down && win.folder < win.folders.length - 1) win.pickFolder(win.folder + 1)
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
                            else if ((k === Qt.Key_Backspace || k === Qt.Key_Delete) && shift && (ctrl || e.modifiers & Qt.MetaModifier)) win.emptyTrash()
                            else if (k === Qt.Key_D || k === Qt.Key_NumberSign || k === Qt.Key_Backspace || k === Qt.Key_Delete) win.trash()
                            else if (k === Qt.Key_Exclam) win.spam()
                            else if (k === Qt.Key_U && shift) win.markAllRead(win.folder)
                            else if (k === Qt.Key_U) win.toggleRead()
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
                            readonly property bool picked: win.picked.indexOf(modelData.thread) >= 0
                            width: ListView.view.width
                            implicitHeight: col.implicitHeight + 28
                            radius: 8
                            color: picked || index === win.current && !win.picked.length ? c.sel : th.hovered ? c.hover : "transparent"
                            // With threads picked, the keyboard's place among them
                            border.color: index === win.current && win.picked.length ? c.line : "transparent"
                            HoverHandler { id: th; cursorShape: Qt.PointingHandCursor }
                            // Dragged sideways (towards the folders) it moves; up and down the list scrolls as before.
                            DragHandler {
                                target: null
                                grabPermissions: PointerHandler.TakeOverForbidden
                                cursorShape: Qt.ClosedHandCursor
                                onActiveChanged: if (active) win.startDrag(row.modelData); else win.drop()
                                onCentroidChanged: if (active) win.dragOver(centroid.scenePosition)
                            }
                            TapHandler {
                                acceptedModifiers: Qt.NoModifier
                                onTapped: { win.open(row.index); list.forceActiveFocus() }
                                onDoubleTapped: if (win.draft()) win.compose("resume"); else win.openWindow(row.index)
                            }
                            // ⇧-click picks the threads from the open one to this; Ctrl-click picks this one or leaves it
                            // out (⌘-click is the desktop's: it moves the window)
                            TapHandler { acceptedModifiers: Qt.ShiftModifier; onTapped: { win.pickRange(row.index); list.forceActiveFocus() } }
                            TapHandler { acceptedModifiers: Qt.ControlModifier; onTapped: { win.togglePick(row.index); list.forceActiveFocus() } }
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
                    // In Trash: emptying it, which asks first
                    Row {
                        Layout.leftMargin: 28
                        Layout.topMargin: 8
                        Layout.bottomMargin: win.note === "" ? 24 : 0
                        visible: win.folders[win.folder].dir === "Trash" && win.threads.length > 0
                        spacing: 8
                        KeyCap { anchors.verticalCenter: parent.verticalCenter; c: win.look; keys: "⌘⇧⌫"; tint: win.look.faint }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Empty Trash"; font.family: c.font; font.pixelSize: 12
                            color: eh.hovered ? c.danger : c.dim
                            HoverHandler { id: eh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.emptyTrash() }
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
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: c.divider }
            }

            // The open thread, or how many are picked and what can be done to them
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Thread {
                    id: reader
                    anchors.fill: parent
                    visible: win.picked.length === 0
                    app: win; c: app.look; nm: app.mailer
                    messages: win.messages
                    htmlMode: win.htmlMode
                    onCycleHtml: win.htmlMode = (win.htmlMode + 1) % 3
                    onResumeDraft: win.compose("resume")
                    actions: win.readerActions
                    onAct: id => win.act(id)
                }
                Column {
                    anchors.centerIn: parent
                    visible: win.picked.length > 0
                    spacing: 28
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.picked.length + " threads selected"
                        color: c.title; font.family: c.font; font.pixelSize: 22; font.weight: Font.Medium
                    }
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2
                        Repeater {
                            // A click does what the key does
                            model: [["a", "Archive", "archive"], ["d", win.folders[win.folder].dir === "Trash" ? "Delete for good" : "Move to Trash", "trash"],
                                    ["!", win.folders[win.folder].dir === "Spam" ? "Not spam" : "Spam", "spam"],
                                    ["u", "Read or unread", "unread"], ["Esc", "Select only one", "single"]]
                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: pickRow.implicitWidth + 24; implicitHeight: 32
                                radius: 8
                                color: ph.hovered ? c.hover : "transparent"
                                HoverHandler { id: ph; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: { win.act(modelData[2]); list.forceActiveFocus() } }
                                Row {
                                    id: pickRow
                                    x: 12; anchors.verticalCenter: parent.verticalCenter
                                    spacing: 14
                                    Item {
                                        width: 44; height: cap.implicitHeight
                                        KeyCap { id: cap; anchors.right: parent.right; c: win.look; keys: modelData[0]; tint: win.look.faint }
                                    }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; color: ph.hovered ? c.text : c.dim; font.family: c.font; font.pixelSize: 13 }
                                }
                            }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Or drag them to a folder"
                        color: c.faint; font.family: c.font; font.pixelSize: 12
                    }
                }
            }
        }

        // What is being dragged: the thread's subject, by the pointer
        Rectangle {
            id: ghost
            visible: win.dragged !== null
            width: Math.min(320, ghostText.implicitWidth + 28); height: 34
            radius: 8
            color: c.solid
            border.color: win.dropFolder >= 0 ? c.primary : c.line
            Text {
                id: ghostText
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: !win.dragged ? "" : win.dragged.length > 1 ? win.dragged.length + " threads" : win.dragged[0].subject || "(no subject)"
                color: c.title; font.family: c.font; font.pixelSize: 12
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

        // Asks before what can't be undone (deleting for good): Enter does it, Esc or a click outside doesn't.
        Rectangle {
            id: confirmPanel
            anchors.fill: parent
            visible: win.confirm !== null
            color: c.scrim
            TapHandler { onTapped: win.confirm = null }
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { const run = win.confirm.run; win.confirm = null; run() }
                else if (e.key === Qt.Key_Escape) win.confirm = null
                e.accepted = true
            }
            Rectangle {
                anchors.centerIn: parent
                width: 520
                height: confirmCol.implicitHeight + 72
                radius: 14
                color: c.solid
                border.color: c.line
                TapHandler {}       // a click inside keeps it open
                Column {
                    id: confirmCol
                    x: 40; y: 36
                    width: parent.width - 80
                    spacing: 18
                    Text { text: win.confirm ? win.confirm.title : ""; color: c.title; font.family: c.font; font.pixelSize: 15; font.weight: Font.Medium }
                    Text { width: parent.width; wrapMode: Text.Wrap; lineHeight: 1.2; text: win.confirm ? win.confirm.detail : ""; color: c.text; font.family: c.font; font.pixelSize: 12 }
                    Row {
                        spacing: 18
                        Row {
                            spacing: 8
                            KeyCap { anchors.verticalCenter: parent.verticalCenter; c: win.look; keys: "⏎"; tint: win.look.faint }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: win.confirm ? win.confirm.action : ""; color: dh.hovered ? c.title : c.danger; font.family: c.font; font.pixelSize: 12
                                HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: { const run = win.confirm.run; win.confirm = null; run() } }
                            }
                        }
                        Row {
                            spacing: 8
                            KeyCap { anchors.verticalCenter: parent.verticalCenter; c: win.look; keys: "esc"; tint: win.look.faint }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Cancel"; color: ch.hovered ? c.text : c.dim; font.family: c.font; font.pixelSize: 12
                                HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: win.confirm = null }
                            }
                        }
                    }
                }
            }
        }

        // Mail's first start, before an account: Enter (or the button) opens Claude Code in a terminal, which sets it up
        // with you by README.md (`nightmail setup`).
        property bool setupStarted: false
        function startSetup() { setupStarted = true; nm.nightmail(["setup"], () => {}) }
        Rectangle {
            id: setupPanel
            anchors.fill: parent
            visible: win.needsAccount
            color: c.scrim
            TapHandler {}       // nothing behind it to click yet
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) win.startSetup()
                e.accepted = true
            }
            Rectangle {
                anchors.centerIn: parent
                width: 560
                height: setupCol.implicitHeight + 72
                radius: 14
                color: c.solid
                border.color: c.line
                Column {
                    id: setupCol
                    x: 40; y: 36
                    width: parent.width - 80
                    spacing: 18
                    Text { text: "Set up your email account"; color: c.title; font.family: c.font; font.pixelSize: 15; font.weight: Font.Medium }
                    Text {
                        width: parent.width; wrapMode: Text.Wrap; lineHeight: 1.2; color: c.text; font.family: c.font; font.pixelSize: 12
                        text: win.setupStarted
                            ? "Claude opens in a terminal and goes through it with you. When it's done, your inbox shows here."
                            : "Mail keeps your mail on this computer, fetched from your provider. Claude can set up the account with you in a terminal, a step at a time: it asks your address and writes the settings. Your password goes only into the login keyring, never to Claude."
                    }
                    Row {
                        spacing: 8
                        KeyCap { anchors.verticalCenter: parent.verticalCenter; c: win.look; keys: "⏎"; tint: win.look.faint }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.setupStarted ? "Open Claude again" : "Set up with Claude"
                            color: setupHover.hovered ? c.title : c.primary; font.family: c.font; font.pixelSize: 12
                            HoverHandler { id: setupHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.startSetup() }
                        }
                    }
                    Text {
                        width: parent.width; wrapMode: Text.Wrap; color: c.faint; font.family: c.font; font.pixelSize: 11
                        text: "To do it yourself: launcher › System › Install › Plugins › Mail has the steps."
                    }
                }
            }
        }

        property alias cheats: sheet.shown

        readonly property var keyHelp: [
            { title: "Read", keys: [["⌥↑ ⌥↓  j k", "Previous, next"], ["⏎", "Open in a window"], ["↑ ↓", "Scroll the message"], ["Space ⇧Space", "Page down, up"], ["h", "HTML or text"],
                                    ["⌘F  /", "Search"], ["Esc", "Clear the search"]] },
            { title: "Act", keys: [["a", "Archive"], ["d  ⌫", "Move to Trash (in Trash: delete)"], ["!", "Spam (in Spam: not spam)"], ["⌘Z", "Undo"], ["u", "Unread (again: read)"], ["⇧U", "Mark all read"], ["⌘R", "Refresh"],
                                   ["⇧↑ ⇧↓  ⇧-click", "Select several"], ["Ctrl-click", "Select or leave out"], ["⌘A", "Select all"]] },
            { title: "Write", keys: [["⌘N  c", "New message"], ["r", "Reply to all"], ["⇧R", "Reply to the sender only"], ["f", "Forward"],
                                     ["⏎", "Continue a draft (in Drafts)"], ["⌘⇧C", "Claude writes the reply"], ["⌘⇧C", "…from the selected text"],
                                     ["⌘⇧A", "Attach files"], ["Ctrl ⏎", "Send"], ["⌘S", "Save in Drafts"], ["Esc", "Close (Esc Esc: throw away)"]] },
            { title: "Folders", keys: [["Ctrl ↑ ↓", "Previous, next"], ["1 – 6", "Go to a folder"], ["Tab ⇧Tab", "Next, previous account"], ["⌘⇧⌫", "Empty Trash"], ["⌘B", "Hide or show"], ["⌘,", "Settings"]] }
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
            accounts: win.accounts
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
                actions: win.windowActions
                onAct: id => win.act(id, mw.msgs)
                focus: true
                Keys.onPressed: e => {
                    const k = e.key
                    keys.pressed(e)             // ? and Ctrl+? show and hide the keys
                    if (k === Qt.Key_Question) {}
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
                    { title: "Read", keys: [["↑ ↓", "Scroll"], ["Space ⇧Space", "Page down, up"], ["h", "HTML or text"], ["Esc  ⌘W", "Close the window"]] },
                    { title: "Write", keys: [["r", "Reply to all"], ["⇧R", "Reply to the sender only"], ["f", "Forward"], ["⌘⇧C", "Claude writes the reply"]] }
                ]
            }
            onVisibleChanged: if (!visible) destroy()
        }
    }
}
