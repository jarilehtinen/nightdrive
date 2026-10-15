import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// What to share, when an app asks to capture the screen (Screen Mirroring, Chromium's Cast, a video call): the whole screen
// (a tile per display) or one window. Replaces Hyprland's own share window: xdg-desktop-portal-hyprland runs
// hypr/scripts/share-picker (hypr/xdph.conf, written by link.sh), which opens this and waits for the answer.
//   qs ipc call sharepicker open <reply fifo> <window list file>
// ←/→ select a tile, Enter picks it (Window shows the windows: ↑/↓ and Enter), Esc goes back or cancels.
// (Not named *Menu.qml: shell.qml treats those as top bar menus.)
PanelWindow {
    id: win
    property bool open: false
    property string reply: ""            // the share-picker script's fifo
    property bool windowsShown: false    // the Window tile was picked: the list of windows
    property int index: 0
    property var windows: []             // [{ id, cls, title, icon }] from xdph's XDPH_WINDOW_SHARING_LIST

    // Tiles: one per display, then Window (when there are windows to share)
    readonly property var tiles: Quickshell.screens.map(s => ({ kind: "screen", name: Quickshell.screens.length > 1 ? s.name : "Screen", glyph: "monitor", output: s.name }))
        .concat(windows.length > 0 ? [{ kind: "window", name: "Window", glyph: "app-window" }] : [])
    readonly property int count: windowsShown ? windows.length : tiles.length

    // xdph's list: id[HC>]class[HT>]title[HE>]address[HA>] for each window; the id is what it wants back
    function parseWindows(text) {
        return text.split("[HA>]").filter(e => e.indexOf("[HC>]") > 0).map(e => {
            const id = e.split("[HC>]")[0], rest = e.split("[HC>]")[1]
            const cls = rest.split("[HT>]")[0], title = rest.split("[HT>]")[1].split("[HE>]")[0]
            return { id: id, cls: cls, title: title || cls, icon: iconFor(cls) }
        }).filter(w => w.cls !== "" && !/^quickshell$|^hyprland-share-picker$/i.test(w.cls))
    }
    // The app's icon by its window class: StartupWMClass first (webapps: chrome-<site>-Default), then the .desktop id,
    // then Quickshell's guess; "" = the generic window glyph
    // A Chromium webapp's window on Wayland is named after its address, not --class:
    // --app=https://app.slack.com/client/T0 → chrome-app.slack.com__client_T0-default (lowercase)
    function webappClass(d) {
        const m = (d.execString || "").match(/--app=https?:\/\/([^\/\s]+)(\/\S*)?/)
        return m ? ("chrome-" + m[1] + "_" + (m[2] || "/").replace(/\//g, "_") + "-default").toLowerCase() : ""
    }
    function iconFor(cls) {
        const c = cls.toLowerCase()
        const all = DesktopEntries.applications.values
        const e = all.find(d => (d.startupClass || "").toLowerCase() === c)
               || all.find(d => d.id.replace(/\.desktop$/, "").toLowerCase() === c)
               || all.find(d => webappClass(d) === c)
               || DesktopEntries.heuristicLookup(cls)
        return e ? e.icon : ""
    }
    function answer(sel) {           // "" = cancelled
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" > "$2"', "_", sel, reply])
        open = false
    }
    function pick(i) {
        if (windowsShown) { if (windows[i]) answer("window:" + windows[i].id); return }
        const t = tiles[i]
        if (!t) return
        if (t.kind === "screen") answer("screen:" + t.output)
        else { windowsShown = true; index = 0 }
    }
    function back() { if (windowsShown) { windowsShown = false; index = tiles.length - 1 } else answer("") }
    function step(d) { if (count > 0) index = (index + d + count) % count }

    FileView { id: listFile; blockLoading: true; printErrors: false }
    IpcHandler {
        target: "sharepicker"
        function open(fifo: string, listPath: string): void {
            if (win.open && win.reply !== "") win.answer("")   // an earlier request still waiting: cancel it
            win.reply = fifo
            listFile.path = ""; listFile.path = listPath
            win.windows = win.parseWindows(listFile.text())
            win.windowsShown = false; win.index = 0; win.open = true
            keys.forceActiveFocus()
        }
        function close(): void { if (win.open) win.answer("") }
    }

    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#99000000"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea { anchors.fill: parent; onClicked: win.answer("") }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape || (e.key === Qt.Key_Backspace && win.windowsShown)) win.back()
            else if (!win.windowsShown && (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab)) win.step(-1)
            else if (!win.windowsShown && (e.key === Qt.Key_Right || e.key === Qt.Key_Tab)) win.step(1)
            else if (win.windowsShown && e.key === Qt.Key_Up) win.step(-1)
            else if (win.windowsShown && e.key === Qt.Key_Down) win.step(1)
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) win.pick(win.index)
            else return
            e.accepted = true
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.max(title.implicitWidth, win.windowsShown ? 560 : tileRow.implicitWidth) + 48
        height: col.implicitHeight + 48
        radius: 16
        color: Theme.launcherBg
        border.color: Theme.primary
        border.width: 2
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors.centerIn: parent
            spacing: 18
            Text {
                id: title
                anchors.horizontalCenter: parent.horizontalCenter
                text: win.windowsShown ? "Share a window" : "Share your screen"
                color: Theme.primary
                font { family: Theme.font; pixelSize: 13; weight: Font.Medium; letterSpacing: 1.2; capitalization: Font.AllUppercase }
            }

            Row {
                id: tileRow
                visible: !win.windowsShown
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                Repeater {
                    model: win.tiles
                    Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool current: win.index === index
                        width: 150; height: 130
                        radius: 12
                        color: current ? Theme.sel : area.containsMouse ? Theme.hover : "transparent"
                        border.color: current ? Theme.primary : "transparent"
                        border.width: 2
                        Column {
                            anchors.centerIn: parent
                            spacing: 10
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Icons.g(tile.modelData.glyph)
                                color: tile.current ? Theme.accent : Theme.text
                                font { family: Icons.family; pixelSize: 40 }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.name
                                color: tile.current ? Theme.accent : Theme.text
                                font { family: Theme.font; pixelSize: 15 }
                            }
                        }
                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: win.index = tile.index
                            onClicked: win.pick(tile.index)
                        }
                    }
                }
            }

            ListView {
                id: list
                visible: win.windowsShown
                width: 560
                height: Math.min(contentHeight, 9 * 48)
                clip: true
                model: win.windowsShown ? win.windows : []
                currentIndex: win.index
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: wrow
                    required property var modelData
                    required property int index
                    readonly property bool current: win.index === index
                    width: list.width; height: 48
                    radius: 10
                    color: current ? Theme.sel : warea.containsMouse ? Theme.hover : "transparent"
                    AppIcon {
                        id: wicon
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        width: 26; height: 26
                        sourceSize: Qt.size(52, 52)
                        name: wrow.modelData.icon
                    }
                    Text {          // no icon found
                        anchors.centerIn: wicon
                        visible: wicon.status !== Image.Ready
                        text: Icons.g("app-window")
                        color: wrow.current ? Theme.accent : Theme.text
                        font { family: Icons.family; pixelSize: 22 }
                    }
                    Text {
                        anchors { left: wicon.right; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: wrow.modelData.title
                        color: wrow.current ? Theme.accent : Theme.text
                        font { family: Theme.font; pixelSize: 14 }
                    }
                    MouseArea {
                        id: warea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.index = wrow.index
                        onClicked: win.pick(wrow.index)
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: win.windowsShown ? "↑ ↓  ·  Enter: share  ·  Esc: back" : "← →  ·  Enter: share  ·  Esc: cancel"
                color: Theme.dim
                font { family: Theme.font; pixelSize: 11 }
            }
        }
    }
}
