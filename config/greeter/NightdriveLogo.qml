import QtQuick
import QtQuick.Effects

// The Nightdrive logo, as on the website (nightdrive.sh): the name in bold JetBrains Mono with a white → lilac → violet
// gradient and a blinking block cursor after it. The big version types itself in once, letter by letter, the cursor riding
// along, then the cursor keeps blinking. A soft violet glow sits behind it.
// `typed: false` skips the intro (shows the whole name at once); `blinks: false` keeps the cursor lit, and
// `keepsCursor: false` lets it go once the name is typed (when something else on screen takes the cursor over).
Item {
    id: logo

    property string name: "Nightdrive"
    property int pixelSize: 72
    property bool typed: true
    property int typeInterval: 75       // ms per letter
    property int startDelay: 900        // the cursor blinks once alone before the first letter
    property bool started: true         // false holds the typing (the login screen waits for its startup sound)
    property bool glow: true
    property bool blinks: true
    property bool keepsCursor: true
    property bool flashes: false        // the cursor flashes white once the name is typed
    property real cursorOpacity: 1      // for fading the cursor out from outside

    readonly property color white: "#ffffff"
    readonly property color lilac: "#e0bff2"
    readonly property color violet: "#c071eb"
    readonly property string font: "JetBrains Mono"

    property int shown: typed ? 0 : name.length
    readonly property bool done: shown >= name.length

    readonly property real gap: 0.12 * pixelSize     // between the last letter and the cursor
    readonly property real textWidth: full.implicitWidth   // the letters alone, for centring without the cursor

    implicitWidth: full.implicitWidth + gap + cursor.width
    implicitHeight: full.implicitHeight

    // Sizes the logo by the whole name, so nothing moves while it types in
    Text {
        id: full
        visible: false
        text: logo.name
        font { family: logo.font; pixelSize: logo.pixelSize; weight: Font.Bold; letterSpacing: -0.04 * logo.pixelSize }
    }

    // The letters typed so far: only a mask for the gradient below
    Text {
        id: letters
        visible: false
        layer.enabled: true
        width: full.implicitWidth; height: full.implicitHeight
        text: logo.name.slice(0, logo.shown)
        color: "white"
        font: full.font
    }
    Rectangle {
        id: fill
        visible: false
        layer.enabled: true
        width: full.implicitWidth; height: full.implicitHeight
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: logo.white }
            GradientStop { position: 0.4; color: logo.lilac }
            GradientStop { position: 1.0; color: logo.violet }
        }
    }
    // The gradient cut to the letters; the glow goes on top of that (a mask would cut the glow too)
    Item {
        width: full.implicitWidth; height: full.implicitHeight
        layer.enabled: logo.glow
        layer.effect: Glow { strength: 0.55; blurMax: 48 }

        MultiEffect {
            anchors.fill: parent
            source: fill
            maskEnabled: true
            maskSource: letters
            maskThresholdMin: 0.4
            maskSpreadAtMin: 0.6
        }
    }

    Rectangle {
        id: cursor
        // Right after the last typed letter; the partial name's advance, as the font is monospaced
        x: (logo.shown === 0 ? 0 : partial.advanceWidth) + logo.gap
        anchors.verticalCenter: parent.verticalCenter
        width: 0.55 * logo.pixelSize; height: logo.pixelSize
        color: logo.violet
        visible: logo.keepsCursor || !logo.done
        // While typing it stays lit, like a real cursor; afterwards it blinks (the website's 1.1 s, half on, half off)
        opacity: (logo.done && blink.off ? 0 : 1) * logo.cursorOpacity

        layer.enabled: logo.glow
        layer.effect: Glow { strength: 0.7; blurMax: 32 }

        // White in an instant, back to violet over a quarter second
        SequentialAnimation on color {
            running: logo.flashes && logo.done
            PropertyAction { value: logo.white }
            PauseAnimation { duration: 70 }
            ColorAnimation { to: logo.violet; duration: 260; easing.type: Easing.OutQuad }
        }
    }
    TextMetrics {
        id: partial
        font: full.font
        text: letters.text
    }

    QtObject {
        id: blink
        property bool off: false
    }
    Timer {
        // Blinks before the first letter too, then pauses while typing
        interval: 550; repeat: true
        running: logo.blinks && (logo.done || logo.shown === 0)
        onTriggered: blink.off = !blink.off
        onRunningChanged: if (!running) blink.off = false
    }
    Timer {
        id: typer
        interval: logo.shown === 0 ? logo.startDelay : logo.typeInterval
        repeat: true
        running: logo.typed && logo.started && !logo.done
        onTriggered: logo.shown++
    }

    component Glow: MultiEffect {
        property real strength: 0.6
        shadowEnabled: true
        shadowColor: logo.violet
        shadowOpacity: strength
        shadowBlur: 1.0
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        autoPaddingEnabled: true
    }

    // Shows the whole name at once (e.g. a key pressed during the intro)
    function finish() { shown = name.length }
}
