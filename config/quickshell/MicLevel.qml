import QtQuick
import Quickshell.Services.Pipewire

// The default microphone's input level for the bar's microphone icon (BarModule.qml), 0..1. Quickshell's peak monitor
// reads it with a "Peak detect" stream, which topbar/scripts/privacy leaves out (else the icon would keep itself on).
// The monitor gives ~50 peaks a second; the level changes only 10 times a second, in steps of the icon's device pixels,
// so the bar isn't redrawn more than it shows.
Item {
    id: l
    property bool active: false
    property int steps: 32         // the icon's height in device pixels
    property real level: 0
    property real hold: 0          // the highest peak since the last step

    PwNodePeakMonitor {
        node: Pipewire.defaultAudioSource
        enabled: l.active
        onPeakChanged: l.hold = Math.max(l.hold, peak)
    }
    // Fast rise, slower fall, so the fill doesn't flicker
    Timer {
        interval: 100; repeat: true; running: l.active
        onTriggered: {
            const v = Math.max(l.hold, l.level * 0.6)
            l.hold = 0
            l.level = v < 0.03 ? 0 : Math.round(v * l.steps) / l.steps
        }
    }
    onActiveChanged: if (!active) { level = 0; hold = 0 }
}
