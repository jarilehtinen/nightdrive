import QtQuick

// Touchpad scrolling for a Flickable (ListView, GridView): put it inside the view. Hyprland's scroll_factor (0.4)
// makes Qt's own scrolling slow and it stops dead when the fingers lift. This moves by the finger's distance
// (× touchScale) and glides on with the last speed, like GTK and Firefox. A mouse wheel keeps Qt's own scrolling.
WheelHandler {
    id: h
    required property Flickable view
    property real touchScale: 2
    property real step: 52          // px per wheel notch when the touchpad sends no pixel distance
    property real speed: 0          // px/s, smoothed
    property double lastT: 0
    target: null
    acceptedDevices: PointerDevice.TouchPad
    onWheel: e => {
        if (e.phase === Qt.ScrollEnd) {
            if (Math.abs(speed) > 150) view.flick(0, speed)
            speed = 0
            return
        }
        view.cancelFlick()
        const dy = e.pixelDelta.y !== 0 ? e.pixelDelta.y * touchScale : e.angleDelta.y / 120 * step
        const max = Math.max(view.originY, view.originY + view.contentHeight - view.height)
        view.contentY = Math.max(view.originY, Math.min(max, view.contentY - dy))
        const now = Date.now(), dt = now - lastT
        lastT = now
        speed = dt > 0 && dt < 100 ? 0.6 * speed + 0.4 * dy / dt * 1000 : 0
    }
}
