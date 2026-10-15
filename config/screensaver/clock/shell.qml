// Nightdrive screensaver 3: a big theme-coloured clock on black. On a change the old digit slides up and out while the new
// one comes up from below in step with it, with a small spring at the end. Run by screensaver/start as its own Quickshell
// instance (qs -p this folder). Exits on any key or mouse movement.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    readonly property int grace: 1000          // ms after start when input is ignored (the window opening sends a mouse event)
    readonly property int slideMs: 600         // one digit's slide
    readonly property real overshoot: 1.3      // the spring: how far past its place a digit goes before settling (OutBack)
    readonly property string face: "Six Caps"  // Google Fonts (OFL), installed by install.sh into ~/.local/share/fonts
    readonly property int weight: Font.Normal  // Six Caps has one weight
    readonly property real fill: 0.8           // the clock's share of the screen width (capped by the height)
    readonly property real shade: 0.5          // the theme colour darkened to this: a saver shouldn't light up the room
    readonly property real gap: 0.32           // space between digits, in digit widths (the font's own spacing is too loose)

    // Theme colours: a separate Quickshell instance can't import ../quickshell, so this reads the file Theme.qml reads
    property var c: ({})
    FileView {
        path: Quickshell.env("HOME") + "/.cache/nightdrive/theme.json"
        onLoaded: { try { root.c = JSON.parse(text()) } catch (e) {} }
    }
    readonly property color bg: "#000000"
    readonly property color base: c.primary || "#c071eb"   // the clock in the theme's main colour, darkened
    readonly property color ink: Qt.rgba(base.r * shade, base.g * shade, base.b * shade, 1)

    property date now: new Date()
    property bool armed: false
    Timer { interval: 1000 - new Date().getMilliseconds(); running: true; repeat: true
            onTriggered: { root.now = new Date(); interval = 1000 - root.now.getMilliseconds() } }
    Timer { interval: root.grace; running: true; onTriggered: root.armed = true }

    function quit() { if (armed) Qt.quit() }

    // The font at 100 px, measured by its ink: every digit cell is as wide as the widest digit plus the gap, so a
    // proportional font doesn't jitter
    FontMetrics { id: fm; font { family: root.face; weight: root.weight; pixelSize: 100 } }
    // (fm.font is read first: a method call isn't a binding dependency, and these would keep the default font's sizes)
    readonly property real inkW: fm.font.family && Math.max(...("0123456789".split("").map(ch => fm.tightBoundingRect(ch).width))) / 100
    readonly property real digitW: inkW * (1 + gap)
    readonly property real colonW: fm.font.family && fm.tightBoundingRect(":").width / 100 + inkW * gap
    readonly property real digitH: fm.font.family && fm.tightBoundingRect("0").height / 100

    // One digit in its own clipped cell. Both glyphs ride the same progress: the old one goes up exactly as the new one comes in
    component Digit: Item {
        id: d
        property string value: "0"
        property real size: 100
        property string shown: value
        property string previous: value
        property real p: 1                      // 0 → 1 over a change
        width: root.digitW * size
        height: root.digitH * size * 1.04       // clipped to the digits' own band: they appear and vanish at its edges
        clip: true
        readonly property real lift: (fm.ascent / 100 - root.digitH * 1.02) * size   // the font's empty space above the digits
        onValueChanged: { previous = shown; shown = value; anim.restart() }
        NumberAnimation { id: anim; target: d; property: "p"; from: 0; to: 1; duration: root.slideMs
                          easing.type: Easing.OutBack; easing.overshoot: root.overshoot }
        Text {
            text: d.previous; font: cur.font; color: root.ink; renderType: cur.renderType
            anchors.horizontalCenter: parent.horizontalCenter
            y: -d.lift - d.height * d.p
            visible: d.p < 1
        }
        Text {
            id: cur
            text: d.shown; color: root.ink
            renderType: Text.CurveRendering    // the default distance-field glyphs turn polygonal at this size
            font { family: root.face; weight: root.weight; pixelSize: d.size }
            anchors.horizontalCenter: parent.horizontalCenter
            y: -d.lift + d.height * (1 - d.p)
        }
    }

    component Pair: Row {
        property string value: "00"
        property real size: 100
        Digit { value: parent.value[0]; size: parent.size }
        Digit { value: parent.value[1]; size: parent.size }
    }

    component Colon: Item {
        property real size: 100
        width: root.colonW * size; height: root.digitH * size * 1.04
        Text { id: t; anchors.horizontalCenter: parent.horizontalCenter; y: -(fm.ascent / 100 - root.digitH * 1.02) * parent.size
               text: ":"; color: root.ink; renderType: Text.CurveRendering
               font { family: root.face; weight: root.weight; pixelSize: parent.size } }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "nightdrive-clock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: root.bg

            // HH:MM:SS, all the same size: six digits and two colons across `fill` of the width, digits at most 55 % of the height
            readonly property real size: Math.min(width * root.fill / (6 * root.digitW + 2 * root.colonW), height * 0.55 / root.digitH)

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: root.quit()

                Row {
                    anchors.centerIn: parent
                    Pair { value: Qt.formatTime(root.now, "HH"); size: win.size }
                    Colon { size: win.size }
                    Pair { value: Qt.formatTime(root.now, "mm"); size: win.size }
                    Colon { size: win.size }
                    Pair { value: Qt.formatTime(root.now, "ss"); size: win.size }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    property point last: Qt.point(-1, -1)
                    // the first report only says where the pointer is (also when a notification over it goes away)
                    onPositionChanged: m => {
                        if (last.x >= 0 && (Math.abs(m.x - last.x) > 2 || Math.abs(m.y - last.y) > 2)) root.quit()
                        last = Qt.point(m.x, m.y)
                    }
                    onPressed: root.quit()
                    onWheel: root.quit()
                }
            }
        }
    }
}
