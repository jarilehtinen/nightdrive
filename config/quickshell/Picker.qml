import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Color picker (Launcher → Tools → Color Picker, script hypr/scripts/color-picker).
// The script takes a screenshot (grim) and opens it here as a fullscreen overlay: the screen is "frozen".
// Next to the cursor: a magnifier circle (pixels enlarged, center pixel highlighted) and the color code.
// Click copies the color (#rrggbb) to the clipboard, Esc / right click cancels.
PanelWindow {
    id: win

    // --- Tunables ---
    readonly property int lens: 170          // magnifier diameter (px)
    readonly property real zoom: 10          // magnification (logical px → screen)

    property bool open: false
    property string shot: ""                 // file:// path to the screenshot
    property real mx: width / 2              // cursor (logical px)
    property real my: height / 2
    readonly property real scale: frozen.sourceSize.width > 0 ? frozen.sourceSize.width / width : 1   // physical px / logical px
    property string hex: ""

    IpcHandler {
        target: "picker"
        function open(path: string): void { win.shot = "file://" + path; win.hex = ""; win.open = true }
        function close(): void { win.finish("") }
    }

    function hh(v) { return (v < 16 ? "0" : "") + v.toString(16) }
    function colorAt(lx, ly) {
        const d = cv.px
        if (!d) return ""
        const w = cv.width
        const x = Math.max(0, Math.min(w - 1, Math.floor(lx * scale)))
        const y = Math.max(0, Math.min(cv.height - 1, Math.floor(ly * scale)))
        const i = (y * w + x) * 4
        return "#" + hh(d[i]) + hh(d[i + 1]) + hh(d[i + 2])
    }
    function finish(color) {
        win.open = false
        cv.px = null
        cv.unloadImage(win.shot)
        if (color !== "")
            Quickshell.execDetached(["bash", "-c", 'printf %s "$1" | wl-copy; notify-send "Color Picker" "$1 copied to clipboard"', "_", color])
    }
    onMxChanged: hex = colorAt(mx, my)
    onMyChanged: hex = colorAt(mx, my)

    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    color: "black"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Image {
        id: frozen
        anchors.fill: parent
        source: win.shot
        cache: false
        smooth: false
        onStatusChanged: if (status === Image.Ready) cv.loadImage(win.shot)
    }

    // Hidden canvas: reads the image pixels (color under the cursor)
    Canvas {
        id: cv
        x: -100000
        width: frozen.sourceSize.width
        height: frozen.sourceSize.height
        property var px: null
        onImageLoaded: requestPaint()
        onPaint: {
            if (!isImageLoaded(win.shot)) return
            const ctx = getContext("2d")
            ctx.drawImage(win.shot, 0, 0)
            px = ctx.getImageData(0, 0, width, height).data
            win.hex = win.colorAt(win.mx, win.my)
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPositionChanged: mouse => { win.mx = mouse.x; win.my = mouse.y }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) win.finish("")
            else win.finish(win.colorAt(mouse.x, mouse.y))
        }
    }
    Item { anchors.fill: parent; focus: true; Keys.onEscapePressed: win.finish("") }

    // Magnifier + color code next to the cursor (flips to the other side near the edge)
    Item {
        id: loupe
        visible: win.open && win.hex !== ""
        width: win.lens
        height: win.lens + 40
        x: win.mx + 26 + width > win.width ? win.mx - 26 - width : win.mx + 26
        y: win.my + 26 + height > win.height ? win.my - 26 - height : win.my + 26

        Item {
            id: mask
            width: win.lens; height: win.lens
            visible: false
            layer.enabled: true
            Rectangle { anchors.fill: parent; radius: width / 2 }
        }
        Item {
            id: glass
            width: win.lens; height: win.lens
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: mask }
            Image {
                source: win.shot
                cache: false
                smooth: false
                width: win.width * win.zoom
                height: win.height * win.zoom
                x: win.lens / 2 - win.mx * win.zoom
                y: win.lens / 2 - win.my * win.zoom
            }
        }
        // Border
        Rectangle { width: win.lens; height: win.lens; radius: width / 2; color: "transparent"; border.color: "#ffffff"; border.width: 3 }
        Rectangle { width: win.lens - 6; height: win.lens - 6; x: 3; y: 3; radius: width / 2; color: "transparent"; border.color: "#cc000000"; border.width: 1 }
        // Center pixel (one physical pixel, magnified)
        Rectangle {
            readonly property real s: win.zoom / win.scale
            width: s; height: s
            x: (win.lens - s) / 2
            y: (win.lens - s) / 2
            color: "transparent"
            border.color: "#ffffff"; border.width: 2
            Rectangle { anchors.fill: parent; anchors.margins: 2; color: "transparent"; border.color: "#000000"; border.width: 1 }
        }
        // Color code
        Rectangle {
            y: win.lens + 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: label.implicitWidth + 44; height: 30; radius: 8
            color: "#e6101014"; border.color: "#44ffffff"; border.width: 1
            Rectangle { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 4; color: win.hex; border.color: "#88ffffff"; border.width: 1 }
            Text {
                id: label
                x: 32; anchors.verticalCenter: parent.verticalCenter
                text: win.hex
                color: "#ffffff"
                font { family: Theme.font; pixelSize: 15 }
            }
        }
    }
}
