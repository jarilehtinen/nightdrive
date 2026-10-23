import QtQuick
import Quickshell
import qs

// Deck (Spotify): track, cover art, playhead, controls and like.
// State is read from $XDG_RUNTIME_DIR/deck/state.json (written by Deck's Linux helper process) and commands
// go through `deck ctl <command>`. The playhead position is extrapolated from the state (Deck only rewrites the file on changes).
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 12

    property var info: null            // state.json: info (title, artist, album, duration_ms, position_ms, playing, cover, liked)
    property bool alive: false         // Deck's helper process is running
    property real updatedMs: 0
    property real nowMs: Date.now()
    property var optimistic: ({})      // pending local changes: { playing, liked }
    property bool outOpen: false       // output device list open
    signal close()
    function openDeck() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/deck-window"])
        m.close()
    }

    readonly property string deckBin: Quickshell.env("HOME") + "/.local/bin/deck"
    readonly property bool playing: optimistic.playing !== undefined ? optimistic.playing : (info !== null && info.playing)
    readonly property var liked: optimistic.liked !== undefined ? optimistic.liked : (info ? info.liked : null)
    readonly property real duration: info ? info.duration_ms : 0
    readonly property real position: {
        if (!info) return 0
        let p = info.position_ms
        if (info.playing) p += nowMs - updatedMs
        return Math.max(0, Math.min(duration, p))
    }

    function fmt(ms) {
        const s = Math.floor(ms / 1000)
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }
    function refresh() { stateProc.running = true }
    function ctl(cmd) {
        Quickshell.execDetached([deckBin, "ctl", cmd])
        settle.restart()
    }
    function toggleLike() {
        if (liked === null || liked === undefined) return
        optimistic = Object.assign({}, optimistic, { liked: !liked })
        ctl("like")
    }
    function togglePlay() {
        optimistic = Object.assign({}, optimistic, { playing: !playing })
        ctl("toggle")
    }
    Component.onCompleted: refresh()

    Timer { interval: 1000; repeat: true; running: true; onTriggered: m.refresh() }
    Timer { interval: 250; repeat: true; running: m.playing; onTriggered: m.nowMs = Date.now() }
    // After a command: wait a moment so the local change doesn't vanish before Deck responds
    Timer { id: settle; interval: 1200; onTriggered: { m.optimistic = ({}); m.refresh() } }

    Sh {
        id: stateProc
        // No state or the process is dead (Deck killed, stale file) -> exit code != 0
        script: 'f="$XDG_RUNTIME_DIR/deck/state.json"; [ -s "$f" ] || exit 3; pid=$(jq -r .pid "$f"); [ -d "/proc/$pid" ] || exit 4; cat "$f"'
        onResult: text => {
            if (stateProc.exitCode !== 0) { m.alive = false; m.info = null; return }
            try {
                const j = JSON.parse(text)
                m.alive = true
                m.info = j.info
                m.updatedMs = j.updated_ms
                m.nowMs = Date.now()
            } catch (e) { m.alive = false; m.info = null }
        }
    }

    MenuHeader { width: parent.width; title: "Music" }

    // --- Deck not running / nothing playing ---
    MenuNote {
        visible: m.alive && m.info === null
        text: "Nothing playing"
    }
    MenuButton {
        visible: !m.alive || m.info === null
        gap: 10   // no divider above it: the room sets it apart
        icon: "music"
        label: m.alive ? "Open Deck" : "Start Deck"
        onClicked: m.openDeck()
    }

    // --- Playing: cover + info ---
    Row {
        visible: m.info !== null
        width: parent.width
        spacing: 14
        Image {
            id: cover
            width: 84; height: 84
            sourceSize: Qt.size(168, 168)
            fillMode: Image.PreserveAspectCrop
            source: m.info && m.info.cover ? m.info.cover : ""
            visible: source !== "" && status === Image.Ready
        }
        Rectangle {          // placeholder when there's no cover art
            width: 84; height: 84; radius: 6
            visible: !cover.visible
            color: Theme.hover
            Text { anchors.centerIn: parent; text: Icons.g("music"); color: Theme.dim; font { family: Icons.family; pixelSize: 30 } }
        }
        Column {
            width: parent.width - 84 - 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                width: parent.width; elide: Text.ElideRight
                text: m.info ? m.info.title : ""
                color: Theme.accent
                font { family: Theme.font; pixelSize: 15; bold: true }
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: m.info ? m.info.artist : ""
                color: Theme.text
                font { family: Theme.font; pixelSize: 13 }
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: m.info ? m.info.album : ""
                color: Theme.dim
                font { family: Theme.font; pixelSize: 12 }
            }
        }
    }

    // Playhead: bar + times (Deck has no seeking, so display only)
    Column {
        visible: m.info !== null
        width: parent.width
        spacing: 5
        Rectangle {
            width: parent.width; height: 4; radius: 2
            color: Theme.border
            Rectangle {
                width: m.duration > 0 ? parent.width * (m.position / m.duration) : 0
                height: parent.height; radius: 2
                color: Theme.accent
            }
        }
        Item {
            width: parent.width; height: 16
            Text { anchors.left: parent.left; text: m.fmt(m.position); color: Theme.dim; font { family: Theme.font; pixelSize: 11 } }
            Text { anchors.right: parent.right; text: m.fmt(m.duration); color: Theme.dim; font { family: Theme.font; pixelSize: 11 } }
        }
    }

    // Controls: previous, play/pause, next + like
    Item {
        visible: m.info !== null
        width: parent.width
        height: 44

        Row {
            anchors.centerIn: parent
            spacing: 26
            Repeater {
                model: [
                    { glyph: "skip-back", size: 22, act: "previous" },
                    { glyph: "play", size: 30, act: "toggle" },
                    { glyph: "skip-forward", size: 22, act: "next" }
                ]
                delegate: Text {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.g(modelData.act === "toggle" ? (m.playing ? "pause" : "play") : modelData.glyph)
                    color: area.containsMouse ? Theme.primary : Theme.text
                    font { family: Icons.family; pixelSize: modelData.size }
                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: area
                        anchors { fill: parent; margins: -8 }
                        hoverEnabled: true
                        onClicked: modelData.act === "toggle" ? m.togglePlay() : m.ctl(modelData.act)
                    }
                }
            }
        }
        Text {
            id: outBtn
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: Icons.g("speaker")
            color: m.outOpen ? Theme.primary : (outArea.containsMouse ? Theme.primary : Theme.dim)
            font { family: Icons.family; pixelSize: 22 }
            MouseArea { cursorShape: Qt.PointingHandCursor; id: outArea; anchors { fill: parent; margins: -8 } hoverEnabled: true; onClicked: m.outOpen = !m.outOpen }
        }
        Text {
            id: heart
            visible: m.liked !== null && m.liked !== undefined
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: Icons.g("heart")
            color: m.liked ? Theme.primary : (heartArea.containsMouse ? Theme.primary : Theme.dim)
            font { family: Icons.family; pixelSize: 22 }
            MouseArea { cursorShape: Qt.PointingHandCursor; id: heartArea; anchors { fill: parent; margins: -8 } hoverEnabled: true; onClicked: m.toggleLike() }
        }
    }

    // Output device (same list as in the Sound menu)
    OutputList { visible: m.info !== null && m.outOpen; active: visible; width: parent.width }

    // While playing: bring up Deck's window (or start it); when nothing is playing the same button is at the top
    MenuButton {
        visible: m.info !== null
        gap: 10
        icon: "music"
        label: "Open Deck"
        onClicked: m.openDeck()
    }
}
