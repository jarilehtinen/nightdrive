pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Which optional parts (plugins.txt, plugin folders) are installed: the ids in ~/.cache/nightdrive/plugins, written by `nightdrive plugins
// installed`. A part that isn't installed doesn't show: Plugins.has("deck") hides the launcher's Music, the player row and
// Ctrl+Space, a top bar module with "needs": "deck" isn't run. hypr/bindings.lua and hypr/scripts/shortcuts read the
// same file. check() runs the tests again when something may have changed: on start, when the launcher opens, when an
// app's .desktop file comes or goes (Flatpak, web apps, GUI packages) and after every dnf transaction (a hook,
// config/system/nightdrive.actions: `sudo dnf install tailscale` has no .desktop file). An installer from
// Install › Plugins updates the file itself. No polling.
Singleton {
    id: pl
    property var ids: []
    function has(id) { return ids.indexOf(id) >= 0 }
    property bool again: false               // a check asked for while one runs: another one after it
    function check() { if (proc.running) again = true; else proc.running = true }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.cache/nightdrive/plugins"; watchChanges: true; onFileChanged: reload(); printErrors: false
        // Only a real change: the same list again would rebuild the launcher's list and lose its selection
        onLoaded: {
            const n = text().split("\n").map(l => l.trim()).filter(l => l !== "")
            if (JSON.stringify(n) !== JSON.stringify(pl.ids)) pl.ids = n
        }
    }
    // Read again when it's done: a file that was missing when Quickshell started isn't watched
    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.local/bin/nightdrive", "plugins", "installed"]
        onExited: { file.reload(); if (pl.again) { pl.again = false; running = true } }
    }
    // Apps added or removed: one check after the burst (the first scan at start and an install change the list many times)
    Connections { target: DesktopEntries.applications; function onValuesChanged() { settle.restart() } }
    Timer { id: settle; interval: 2000; onTriggered: pl.check() }
    // dnf's hook touches this (created by install.sh, so that it is watched from the start)
    FileView { path: "/var/lib/nightdrive/dnf-changed"; watchChanges: true; onFileChanged: pl.check(); printErrors: false }
    Component.onCompleted: check()
}
