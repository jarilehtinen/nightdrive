import QtQuick
import Quickshell

// An app's icon by its name (a .desktop file's Icon=), a path or a URL. Qt reads the icon themes once, when Quickshell
// starts, so an app installed after that (Tuba from Install › Software) wasn't found by name. Then the usual places are
// tried as files, one after another until one loads.
Image {
    id: img
    property string name: ""
    property int attempt: 0
    readonly property string home: Quickshell.env("HOME")
    readonly property var candidates: {
        const n = name
        if (n === "") return []
        if (n.indexOf("://") > 0) return [n]
        if (n.startsWith("/")) return ["file://" + n]
        // An icon of your own in ~/.local/share/icons/hicolor wins: Qt's lookup finds the system's first (link.sh puts
        // Steam's logo there over Fedora Asahi's locomotive). One failed load for every other icon.
        const out = ["file://" + home + "/.local/share/icons/hicolor/scalable/apps/" + n + ".svg"]
        const themed = Quickshell.iconPath(n, true)
        if (themed !== "") out.push(themed)
        for (const base of ["/usr/share/icons/hicolor", home + "/.local/share/flatpak/exports/share/icons/hicolor",
                            "/var/lib/flatpak/exports/share/icons/hicolor", home + "/.local/share/icons/hicolor"])
            for (const f of ["scalable/apps/" + n + ".svg", "256x256/apps/" + n + ".png", "128x128/apps/" + n + ".png",
                             "64x64/apps/" + n + ".png", "48x48/apps/" + n + ".png"])
                out.push("file://" + base + "/" + f)
        out.push("file:///usr/share/pixmaps/" + n + ".png", "file:///usr/share/pixmaps/" + n + ".svg")
        return out
    }
    onCandidatesChanged: attempt = 0
    source: attempt < candidates.length ? candidates[attempt] : ""
    onStatusChanged: if (status === Image.Error && attempt < candidates.length) attempt++
    fillMode: Image.PreserveAspectFit
}
