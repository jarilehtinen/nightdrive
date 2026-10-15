import QtQuick

// Touchpad scrolling for a Flickable (ListView, GridView): put it inside the view. Qt's own touchpad scrolling
// is slow and it stops dead when the fingers lift. This moves by the finger's distance
// (× touchScale) and glides on with the swipe's speed, like GTK and Firefox. A new swipe in the same direction
// while the list is still gliding adds to the speed. A mouse wheel keeps Qt's own scrolling.
// The glide is our own (Flickable.flick() is ignored when a swipe interrupted the previous glide).
WheelHandler {
    id: h
    required property Flickable view
    property real touchScale: 0.8   // with Hyprland's scroll_factor 1.0 (app speeds: hypr/scroll.lua)
    property real step: 52          // px per wheel notch when the touchpad sends no pixel distance
    property real tau: 0.45         // glide's time constant (s): it travels speed × tau
    property real maxSpeed: 12000   // px/s
    property var samples: []        // [time ms, dy] of the current swipe, the last 100 ms
    property double lastT: 0
    property real carry: 0          // the glide's speed when this swipe started (px/s, + = content moves down)
    property real speed: 0          // the glide's current speed
    property real setY: 0           // the contentY we set last: anything else (keys, hover) stops the glide
    target: null
    acceptedDevices: PointerDevice.TouchPad

    // Scrolls by dy (+ = towards the top); false when it hit either end
    function scrollBy(dy) {
        const max = Math.max(view.originY, view.originY + view.contentHeight - view.height)
        const want = view.contentY - dy
        const y = Math.max(view.originY, Math.min(max, want))
        view.contentY = y
        setY = y
        return y === want
    }

    property FrameAnimation glide: FrameAnimation {
        onTriggered: {
            if (Math.abs(h.view.contentY - h.setY) > 0.5) { stop(); h.speed = 0; return }
            const dt = Math.min(frameTime, 0.05)
            h.speed *= Math.exp(-dt / h.tau)
            if (Math.abs(h.speed) < 20 || !h.scrollBy(h.speed * dt)) { stop(); h.speed = 0 }
        }
    }

    onWheel: e => {
        const now = Date.now()
        if (e.phase === Qt.ScrollEnd) {
            // Fingers that stopped before lifting: no glide
            let v = 0
            if (samples.length > 0 && now - lastT < 60) {
                const span = Math.max(now - samples[0][0], 16)
                v = samples.reduce((a, s) => a + s[1], 0) / span * 1000
            }
            if (v !== 0 && Math.sign(v) === Math.sign(carry)) v += carry
            samples = []; carry = 0
            if (Math.abs(v) > 150) {
                speed = Math.max(-maxSpeed, Math.min(maxSpeed, v))
                setY = view.contentY
                glide.start()
            }
            return
        }
        if (samples.length === 0 || now - lastT > 150) {      // a new swipe: catch the glide
            carry = glide.running ? speed : 0
            samples = []
        }
        glide.stop(); speed = 0
        view.cancelFlick()
        const dy = e.pixelDelta.y !== 0 ? e.pixelDelta.y * touchScale : e.angleDelta.y / 120 * step
        scrollBy(dy)
        lastT = now
        samples = samples.filter(s => now - s[0] <= 100).concat([[now, dy]])
    }
}
