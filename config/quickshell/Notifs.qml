pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Notification server (org.freedesktop.Notifications; replaced mako on 14.10.2026). NotificationPopups.qml draws the popups,
// NotificationsMenu.qml the history. The app's icon comes from its .desktop file, so every notification shows one.
// Like mako's ignore-timeout: every popup goes after `timeout` whatever the app asks (Chromium and nm-applet ask for never);
// critical ones stay until clicked. Do not disturb hides the popups, the history keeps them.
//   qs ipc call notifications toggleDnd     → "true" when do not disturb is now on (hypr/scripts/dnd, F6)
//   qs ipc call notifications dismissAll | clear | count
Singleton {
    id: s

    readonly property int timeout: 5000       // ms a popup stays (hover keeps it)
    readonly property int maxHistory: 50
    readonly property int maxPopups: 6

    property var popups: []                   // [{ uid, n (Notification), entry (history row) }], newest first
    property var history: []                  // [{ uid, app, summary, body, icon, image, preview, entry, time }], newest first
    property alias dnd: persist.dnd
    property double now: Date.now()           // for "2 min ago": updated every 30 s
    // The notification menu is open (NotificationsMenu.qml): the popups go (the menu lists them) and new ones skip the
    // popup, they show up in the menu's list
    property bool menuOpen: false
    onMenuOpenChanged: if (menuOpen) dismissAll()

    // Survive Quickshell's reload on save (a restart still starts empty, as mako did). The history goes over as JSON
    // text: a JS array can't move to the reloaded config's engine ("JSValue can't be reassigned"), it came back undefined.
    PersistentProperties {
        id: persist
        reloadableId: "notifs"
        property string historyJson: "[]"
        property bool dnd: false
        property int uid: 0
        onLoaded: { try { s.history = JSON.parse(historyJson) } catch (e) { s.history = [] } }
    }
    onHistoryChanged: persist.historyJson = JSON.stringify(history)
    Timer { interval: 30000; repeat: true; running: true; onTriggered: s.now = Date.now() }

    // "now", "5 min", "2 h", then the time of day
    function ago(t) {
        const m = Math.floor((now - t) / 60000)
        if (m < 1) return "now"
        if (m < 60) return m + " min"
        if (m < 6 * 60) return Math.floor(m / 60) + " h"
        return Qt.formatTime(new Date(t), "HH:mm")
    }

    // Icons for names the icon theme doesn't have (blueman's headphones), recoloured by hypr/scripts/theme
    readonly property string ownIcons: Quickshell.env("HOME") + "/.cache/nightdrive/notify-icons/32x32/devices/"
    readonly property var ownIconNames: ["audio-headphones", "audio-headset"]
    function iconPath(name) {
        if (!name) return ""
        if (name.startsWith("lucide:")) return name   // a Lucide glyph (NotificationCard.qml draws it from the font)
        if (name.startsWith("/")) return "file://" + name
        if (name.indexOf("://") > 0) return name
        if (ownIconNames.indexOf(name) >= 0) return "file://" + ownIcons + name + ".svg"
        return Quickshell.iconPath(name, true)
    }
    // The app's .desktop entry: the desktop-entry hint, else by the app's name ("Firefox" → org.mozilla.firefox,
    // "Telegram Desktop" → org.telegram.desktop). DesktopEntries.heuristicLookup finds neither of those.
    function desktopEntry(n) {
        const all = DesktopEntries.applications.values
        const id = e => (e.id || "").replace(/\.desktop$/, "").toLowerCase()
        if (n.desktopEntry) {
            const want = n.desktopEntry.replace(/\.desktop$/, "").toLowerCase()
            const hit = all.find(e => id(e) === want)
            if (hit) return hit
        }
        const a = (n.appName || "").trim().toLowerCase()
        if (a === "") return null
        const dotted = a.replace(/\s+/g, ".")
        const first = a.split(/\s+/)[0]
        return all.find(e => id(e) === a || id(e).split(".").pop() === a || (e.name || "").toLowerCase() === a
                             || (e.startupClass || "").toLowerCase() === a)
            || all.find(e => id(e).endsWith("." + dotted) || (e.name || "").toLowerCase() === first || id(e).startsWith(a + "-"))   // blueman → blueman-manager
            || null
    }

    function remove(uid) { popups = popups.filter(p => p.uid !== uid) }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: false
        persistenceSupported: true
        onNotification: n => {
            // A replacement (same id) updates the Notification already shown: move it to the top as new
            const old = s.popups.find(p => p.n === n)
            const e = s.desktopEntry(n)
            // Quickshell hands an icon name sent as the notification's picture as image://icon/<name>: a name we look up
            // ourselves (the icon provider draws a checkerboard for one the theme doesn't have)
            const named = n.image.startsWith("image://icon/") ? n.image.slice(13) : ""
            // The app's icon as a name (AppIcon finds it even when the app was installed after Quickshell started), or
            // an icon named like the app (blueman)
            const lower = (n.appName || "").toLowerCase()
            const appIcon = (e && e.icon) || (lower && Quickshell.iconPath(lower, true) ? lower : "")
            const own = s.iconPath(n.appIcon || named)
            // The same notification again: a replacement, or one still shown when Quickshell reloaded (the server keeps
            // it and hands it over again). Its history row is updated, not added twice.
            const prev = s.history.find(h => h.nid === n.id)
            const same = prev && prev.summary === n.summary && prev.body === n.body
            const row = {
                uid: old ? old.uid : prev ? prev.uid : ++persist.uid,
                nid: n.id,
                app: n.appName || (e ? e.name : ""),
                summary: n.summary, body: n.body,
                // The app's icon; the notification's own picture (an avatar, a cover) goes to the right, and so does
                // a device icon (blueman's headphones). Any other app_icon is the app's own icon again: shown once.
                icon: appIcon || own,
                image: (n.image && !named ? n.image : "") || (appIcon && s.ownIconNames.indexOf(n.appIcon || named) >= 0 ? own : ""),
                // A picture to show under the text, not as a square (screenshots: hypr/scripts/screenshot)
                preview: !!n.image && !named && (n.hints || {}).category === "x-nightdrive.preview",
                entry: n.desktopEntry || (e ? e.id : ""),
                time: same ? prev.time : Date.now(),
                critical: n.urgency === NotificationUrgency.Critical
            }
            s.history = [row].concat(s.history.filter(h => h.uid !== row.uid)).slice(0, s.maxHistory)
            if (s.dnd || s.menuOpen) { n.expire(); return }
            n.tracked = true
            if (!old) n.closed.connect(() => s.remove(row.uid))
            s.popups = [{ uid: row.uid, n: n, entry: row }].concat(s.popups.filter(p => p.uid !== row.uid))
            // Too many: the oldest go (into the history only)
            for (const p of s.popups.slice(s.maxPopups)) p.n.expire()
        }
    }

    // A click on a popup: the app's default action if it has one, otherwise its window comes up (hypr/scripts/focus-app)
    function activate(p) {
        const def = p.n.actions.find(a => a.identifier === "default")
        if (!def) openApp(p.entry)
        if (def) def.invoke()              // closes the notification unless the app marked it resident
        if (p.n && !p.n.resident) p.n.dismiss()
        remove(p.uid)
    }
    // The notification menu: a row's app comes up; × forgets a row (and its popup, if it's still shown)
    function openApp(row) {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/focus-app", row.app, row.entry])
    }
    function forget(uid) {
        history = history.filter(h => h.uid !== uid)
        const p = popups.find(p => p.uid === uid)
        if (p) p.n.dismiss()
    }
    function dismissAll() { for (const p of popups.slice()) p.n.dismiss() }

    IpcHandler {
        target: "notifications"
        function toggleDnd(): string { s.dnd = !s.dnd; if (s.dnd) s.dismissAll(); return String(s.dnd) }
        function setDnd(on: bool): void { s.dnd = on; if (on) s.dismissAll() }
        function getDnd(): string { return String(s.dnd) }
        function dismissAll(): void { s.dismissAll() }
        function clear(): void { s.history = [] }
        function count(): int { return s.history.length }
    }
}
