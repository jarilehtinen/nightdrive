import QtQuick
import Quickshell

// The login screen's look, shared by the greeter (shell.qml, greetd) and the lock at startup (lock.qml): wallpaper, title,
// password field and an error line. The caller does the authentication and sets busy/message (and clears message on typing).
Item {
    id: view

    property bool busy: false
    property string message: ""
    signal submitted(string password)
    signal escapePressed()
    signal typing()

    readonly property string title: "Nightdrive"
    readonly property string wallpaper: Quickshell.shellDir + "/background.jpg"

    readonly property color bg: "#1a1b26"
    readonly property color field: "#0b0b0d"
    readonly property color text: "#c0caf5"
    readonly property color dim: "#565f89"
    readonly property color accent: "#e0bff2"
    readonly property color violet: "#c071eb"
    readonly property color danger: "#f7768e"
    readonly property string font: "JetBrains Mono"

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

    Column {
        anchors.centerIn: parent
        spacing: 28

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: view.title
            color: view.accent
            font { family: view.font; pixelSize: 34; weight: Font.Light; letterSpacing: 6 }
        }

        Rectangle {
            id: box
            anchors.horizontalCenter: parent.horizontalCenter
            width: 340; height: 48
            radius: 12
            color: view.field
            border.width: 2
            border.color: input.activeFocus ? view.violet : "#2e2833"
            opacity: view.busy ? 0.6 : 1

            TextInput {
                id: input
                anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: view.text
                selectionColor: "#35253d"
                font { family: view.font; pixelSize: 18 }
                enabled: !view.busy
                focus: true
                onAccepted: { if (text !== "" && !view.busy) view.submitted(text); text = "" }
                Keys.onEscapePressed: view.escapePressed()
                onTextChanged: if (text !== "") view.typing()
            }
            Text {
                anchors.centerIn: parent
                visible: input.text === "" && !view.busy
                text: "Password"
                color: view.dim
                font { family: view.font; pixelSize: 16 }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 20
            text: view.message
            color: view.danger
            font { family: view.font; pixelSize: 14 }
        }
    }
}
