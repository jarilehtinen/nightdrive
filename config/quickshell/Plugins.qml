pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Which optional parts (plugins.txt) are installed: the ids in ~/.cache/nightdrive/plugins, written by `nightdrive plugins
// installed`. A part that isn't installed doesn't show: Plugins.has("deck") hides the launcher's Music, the player row and
// Ctrl+Space, a top bar module with "needs": "deck" isn't run. hypr/bindings.lua and hypr/scripts/shortcuts read the
// same file. check() runs the tests again (on start, when the launcher opens and every 30 s), so a part installed or
// removed by hand (`sudo dnf install tailscale`) shows up or goes away by itself; an installer from Install › Plugins
// updates the file at once.
Singleton {
    id: pl
    property var ids: []
    function has(id) { return ids.indexOf(id) >= 0 }
    function check() { if (!proc.running) proc.running = true }

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
    Process { id: proc; command: [Quickshell.env("HOME") + "/.local/bin/nightdrive", "plugins", "installed"]; onExited: file.reload() }
    Timer { interval: 30000; repeat: true; running: true; onTriggered: pl.check() }
    Component.onCompleted: check()
}
