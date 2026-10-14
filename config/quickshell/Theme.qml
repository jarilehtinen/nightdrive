pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Menu colours. The theme colour (Settings › Theme › Color) is read from ~/.cache/nightdrive/theme.json,
// written by hypr/scripts/theme; changes show up immediately. Defaults (violet, the same as BASE in that script) if the file doesn't exist.
Singleton {
    id: t
    property var c: ({})
    FileView {
        path: Quickshell.env("HOME") + "/.cache/nightdrive/theme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { t.c = JSON.parse(text()) } catch (e) {} }
    }

    readonly property color bg:      "#0b0b0d"                    // menu background
    readonly property color hover:   c.hover   || "#1f1528"       // row under the mouse
    readonly property color sel:     c.sel     || "#35253d"       // selected/active row (same as the active workspace)
    readonly property color border:  c.border  || "#3a2f45"
    readonly property color text:    c.text    || "#c9bdd3"
    readonly property color dim:     c.dim     || "#9486a3"
    readonly property color accent:  c.accent  || "#e0bff2"       // selected text and icons
    readonly property color primary: c.primary || "#c071eb"       // borders and highlights (the theme's main colour)
    readonly property color danger:  "#f7768e"                    // state colours (Tokyo Night red / orange / green); the theme doesn't change them
    readonly property color warning: "#ff9e64"
    readonly property color caution: "#e0af68"                    // yellow: the middle step of a three-step meter (SystemMenu)
    readonly property color ok:      "#9ece6a"
    readonly property color launcherBg: "#f71a1b26"               // kitty background (#1a1b26) at 97 % opacity
    readonly property string font:   "JetBrains Mono"
    readonly property int barHeight: 37                           // the top bar (Bar.qml)
    readonly property int notchWidth: 190                         // about the MacBook's notch (14", scale 2), centred on the top edge
}
