import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

// Login screen (greetd + Quickshell, runs in its own Hyprland session, see hyprland-greeter.lua).
// Password only; user and title below. Preview in the current session: `qs -p ~/.config/greeter` (Esc closes, no login is performed).
ShellRoot {
    id: root

    // --- Settings ---
    readonly property string user: "@USER@"   // install.sh fills in the user who installs it
    readonly property string title: "Nightdrive"
    readonly property string wallpaper: Quickshell.shellDir + "/background.jpg"
    readonly property var sessionCommand: ["start-hyprland"]

    readonly property color bg: "#1a1b26"
    readonly property color field: "#0b0b0d"
    readonly property color text: "#c0caf5"
    readonly property color dim: "#565f89"
    readonly property color accent: "#e0bff2"
    readonly property color violet: "#c071eb"
    readonly property color danger: "#f7768e"
    readonly property string font: "JetBrains Mono"

    property string pending: ""     // typed password, waiting for PAM's prompt
    property string message: ""
    property bool busy: false

    function submit(pw) {
        if (busy || pw === "") return
        busy = true; message = ""; pending = pw
        if (!Greetd.available) { demo.start(); return }
        Greetd.createSession(user)
    }
    function reset(msg) { busy = false; pending = ""; message = msg; Greetd.cancelSession() }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) { Greetd.respond(root.pending); root.pending = "" }
        }
        function onAuthFailure(message) { root.reset("Wrong password") }
        function onReadyToLaunch() { Greetd.launch(root.sessionCommand, [], true) }
        function onError(error) { root.reset(error) }
    }
    // Preview without greetd: shows an error
    Timer { id: demo; interval: 600; onTriggered: { root.busy = false; root.pending = ""; root.message = "Preview mode: no login" } }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        color: root.bg
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Image {
            anchors.fill: parent
            source: root.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle { anchors.fill: parent; color: root.bg; opacity: 0.72 }

        Column {
            anchors.centerIn: parent
            spacing: 28

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.title
                color: root.accent
                font { family: root.font; pixelSize: 34; weight: Font.Light; letterSpacing: 6 }
            }

            Rectangle {
                id: box
                anchors.horizontalCenter: parent.horizontalCenter
                width: 340; height: 48
                radius: 12
                color: root.field
                border.width: 2
                border.color: input.activeFocus ? root.violet : "#2e2833"
                opacity: root.busy ? 0.6 : 1

                TextInput {
                    id: input
                    anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: root.text
                    selectionColor: "#35253d"
                    font { family: root.font; pixelSize: 18 }
                    enabled: !root.busy
                    focus: true
                    onAccepted: { root.submit(text); text = "" }
                    Keys.onEscapePressed: if (!Greetd.available) Qt.quit()
                    onTextChanged: if (text !== "") root.message = ""
                }
                Text {
                    anchors.centerIn: parent
                    visible: input.text === "" && !root.busy
                    text: "Password"
                    color: root.dim
                    font { family: root.font; pixelSize: 16 }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 20
                text: root.message
                color: root.danger
                font { family: root.font; pixelSize: 14 }
            }
        }
    }
}
