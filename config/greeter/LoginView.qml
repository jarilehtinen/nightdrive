import QtQuick
import Quickshell

// The login screen's look, shared by the greeter (shell.qml, greetd) and the lock at startup (lock.qml): wallpaper, logo,
// password prompt, an error line and the sounds. The caller does the authentication and sets busy/message (and clears
// message on typing).
Item {
    id: view

    property bool busy: false
    property string message: ""
    signal submitted(string password)
    signal escapePressed()
    signal typing()

    readonly property string title: "Nightdrive"
    readonly property string wallpaper: Quickshell.shellDir + "/background.jpg"
    // The beeps (sounds/generate.py: keys/); the greeter has its copy in /etc/greetd/greeter/sounds
    readonly property string sounds: Quickshell.shellDir + "/sounds/"

    readonly property color bg: "#1a1b26"
    readonly property color text: "#c0caf5"
    readonly property color accent: "#e0bff2"
    readonly property color violet: "#c071eb"
    readonly property color danger: "#f7768e"
    readonly property string font: "JetBrains Mono"
    readonly property int promptSize: 20
    readonly property real cell: 0.6 * promptSize      // a character cell of the monospaced font
    property bool promptShown: false

    function beep(name) { Quickshell.execDetached(["pw-play", "--volume", "0.7", view.sounds + name + ".wav"]) }
    // The startup sound as the screen appears (it swells in slowly while the logo's cursor waits), a PC's power-on beep
    // as the prompt is printed
    Component.onCompleted: beep("startup")
    onPromptShownChanged: if (promptShown) beep("prompt")

    // Gives the keyboard back to the field after busy (a disabled TextInput loses its focus)
    onBusyChanged: if (!busy) input.forceActiveFocus()

    Rectangle { anchors.fill: parent; color: view.bg }
    Image {
        anchors.fill: parent
        source: view.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle { anchors.fill: parent; color: view.bg; opacity: 0.72 }

    // A retro prompt: the logo types itself in, its cursor flashes and fades, then PASSWORD? is printed with a cursor of
    // its own: one cursor on screen at a time.
    // Errors read like a C64's (?WRONG PASSWORD ERROR) on the line above the prompt.
    // The logo is centred by its letters (so its cursor going out moves nothing); the prompt by "PASSWORD? █", and what
    // you type runs on to the right of that, like on a terminal.
    Item {
        anchors.centerIn: parent
        width: parent.width
        height: logo.height + 34 + promptBlock.height

        NightdriveLogo {
            id: logo
            x: Math.round((parent.width - textWidth) / 2)
            name: view.title
            pixelSize: 44
            // N appears with the startup sound's first sparkle: 0.5 s into the sound, plus ~100 ms for pw-play to reach
            // the speakers (~65 ms measured at the sink, the rest by ear: the speakers' own processing)
            startDelay: 600
            blinks: false
            flashes: true
            keepsCursor: !view.promptShown      // the cursor moves down to the prompt when that shows
        }
        // After its white flash the logo's cursor fades out, then the prompt is printed with the cursor of its own
        SequentialAnimation {
            running: logo.done
            PauseAnimation { duration: 330 }            // the flash (NightdriveLogo: 70 ms white, 260 ms back)
            NumberAnimation { target: logo; property: "cursorOpacity"; to: 0; duration: 600; easing.type: Easing.InOutQuad }
        }
        // A moment after the name is typed, the prompt is printed
        Timer {
            interval: 1400
            running: logo.done && !view.promptShown
            onTriggered: view.promptShown = true
        }

        Column {
            id: promptBlock
            x: Math.round((parent.width - label.implicitWidth - 2 * view.cell) / 2)
            y: logo.height + 34
            spacing: 10
            visible: view.promptShown

            Text {
                height: 22
                text: view.message === "" ? "" : view.message === "Wrong password" ? "?WRONG PASSWORD ERROR"
                                                                                   : "?" + view.message.toUpperCase()
                color: view.danger
                font { family: view.font; pixelSize: view.promptSize }
            }

            Row {
                id: prompt
                spacing: view.cell

                Text {
                    id: label
                    text: "PASSWORD?"
                    color: view.accent
                    font { family: view.font; pixelSize: view.promptSize; weight: Font.Bold }
                }

                // Room for ~24 characters, so the prompt doesn't grow as you type; a longer password scrolls
                Item {
                    width: 24 * view.cell; height: input.implicitHeight
                    clip: true

                    TextInput {
                        id: input
                        width: parent.width
                        echoMode: TextInput.Password
                        passwordCharacter: "*"
                        passwordMaskDelay: 0
                        color: view.text
                        selectionColor: "#35253d"
                        // No ligatures: JetBrains Mono draws *** as one shape, its middle star raised
                        font { family: view.font; pixelSize: view.promptSize; weight: Font.Bold; features: { "liga": 0, "calt": 0 } }
                        enabled: !view.busy
                        focus: true
                        onAccepted: { if (text !== "" && !view.busy) view.submitted(text); text = "" }
                        Keys.onEscapePressed: view.escapePressed()
                        // A beep per key press, the return key's too
                        Keys.onPressed: event => {
                            if (!view.busy && !event.isAutoRepeat && (event.text !== "" || event.key === Qt.Key_Backspace))
                                view.beep("key")
                        }
                        onTextChanged: if (text !== "") { logo.finish(); view.promptShown = true; view.typing() }

                        // A block cursor, a character cell wide; it blinks faster while the password is checked
                        cursorDelegate: Rectangle {
                            width: view.cell; height: input.cursorRectangle.height
                            color: view.violet
                            // Lights up when the logo's cursor goes out: one cursor on screen at a time. Opacity, not
                            // visible: TextInput sets its cursor's visible itself
                            opacity: view.promptShown && (input.activeFocus || view.busy) && blinker.lit ? 1 : 0

                            QtObject { id: blinker; property bool lit: true }
                            Timer {
                                id: blinkTimer
                                interval: view.busy ? 120 : 550; repeat: true; running: true
                                onTriggered: blinker.lit = !blinker.lit
                            }
                            // Typing keeps it lit, like a real cursor
                            Connections {
                                target: input
                                function onTextChanged() { blinker.lit = true; blinkTimer.restart() }
                            }
                            // ... and it starts lit when the prompt is printed
                            Connections {
                                target: view
                                function onPromptShownChanged() { blinker.lit = true; blinkTimer.restart() }
                            }
                        }
                    }
                }
            }
        }
    }
}
