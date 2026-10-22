import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// AirPods settings in the middle of the screen, over everything: the AirPods' own settings (each with a short explanation)
// and Nightdrive's ear detection. Opened by the headphones menu and the launcher (Settings › Sound › Headphones): qs ipc call airpods open
// Values from topbar/scripts/eq info (hypr/scripts/headphones-ctl reads them from the AirPods); a change goes through
// eq airpods <setting> <value> and shows at once. Esc or a click outside closes.
// (Not named *Menu.qml: shell.qml treats those as top bar menus.)
PanelWindow {
    id: win
    property bool open: false
    property var info: ({})
    property var over: ({})      // changes on their way to the AirPods: shown until eq info reports them
    readonly property string eq: Quickshell.env("HOME") + "/.config/topbar/scripts/eq"
    readonly property var ap: info.airpods || null
    readonly property var values: Object.assign({}, ap ? ap.settings : {}, over)
    readonly property var pods: ap ? ap.pods : ({})
    // "Jari (AirPods Pro 3)" -> "AirPods Pro 3"
    readonly property string model: ((info.name || "").match(/AirPods[^)]*/) || ["AirPods"])[0].trim()

    function show() { over = ({}); open = true; infoProc.running = true; keys.forceActiveFocus() }
    function setValue(key, v) {
        over = Object.assign({}, over, { [key]: v })
        overGiveUp.restart()
        Quickshell.execDetached([eq, "airpods", key, String(v === true ? 1 : v === false ? 0 : v)])
        refreshSoon.restart()
    }

    IpcHandler {
        target: "airpods"
        function open(): void { win.show() }
        function toggle(): void { if (win.open) win.open = false; else win.show() }
        function close(): void { win.open = false }
    }

    Timer { interval: 2000; repeat: true; running: win.open; onTriggered: infoProc.running = true }
    Timer { id: refreshSoon; interval: 400; onTriggered: infoProc.running = true }
    Timer { id: overGiveUp; interval: 5000; onTriggered: win.over = ({}) }
    Sh {
        id: infoProc
        command: [win.eq, "info"]
        onResult: text => {
            try { win.info = JSON.parse(text) } catch (e) { return }
            // a change the AirPods now report is no longer pending
            const s = win.ap ? win.ap.settings : {}, left = {}
            for (const k in win.over) if (s[k] !== win.over[k]) left[k] = win.over[k]
            win.over = left
        }
    }

    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#99000000"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea { anchors.fill: parent; onClicked: win.open = false }
    Item {
        id: keys
        focus: true
        Keys.onPressed: e => { if (e.key === Qt.Key_Escape) { win.open = false; e.accepted = true } }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 820
        height: body.implicitHeight + 52
        radius: 12
        color: Theme.launcherBg
        border.color: Theme.primary
        border.width: 2
        MouseArea { anchors.fill: parent }

        Column {
            id: body
            x: 30; y: 26
            width: parent.width - 60
            spacing: 22

            Item {   // header: icon, name and model, battery, close
                width: parent.width; height: 44
                Rectangle {
                    id: badge
                    width: 44; height: 44; radius: 22
                    color: Theme.primary
                    Text { anchors.centerIn: parent; text: Icons.g("headphones"); color: Theme.bg; font { family: Icons.family; pixelSize: 22 } }
                }
                Column {
                    anchors { left: badge.right; leftMargin: 14; right: bat.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 3
                    Text { text: win.model; color: Theme.accent; font { family: Theme.font; pixelSize: 18; weight: Font.DemiBold } }
                    Text {
                        text: [win.info.name || "Not connected", win.ap && win.ap.model ? win.ap.model : ""].filter(s => s).join(" · ")
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: 12 }
                    }
                }
                Row {
                    id: bat
                    anchors { right: closeBtn.left; rightMargin: 20; verticalCenter: parent.verticalCenter }
                    spacing: 14
                    Repeater {
                        model: ["left", "right", "case"].filter(k => win.pods[k])
                        Text {
                            required property string modelData
                            readonly property var p: win.pods[modelData]
                            textFormat: Text.StyledText
                            text: ({ left: "L", right: "R", case: "Case" })[modelData] + " <font color=\"" +
                                  (p.charging ? Theme.ok : p.stale ? Theme.dim : p.level < 20 ? Theme.danger : Theme.text) + "\">" + p.level + "%</font>"
                            color: Theme.dim
                            font { family: Theme.font; pixelSize: 12 }
                        }
                    }
                }
                Rectangle {
                    id: closeBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 32; height: 32; radius: 6
                    color: Qt.rgba(1, 1, 1, closeArea.containsMouse ? 0.10 : 0.05)   // hover: a little lighter, not the theme colour
                    Text { anchors.centerIn: parent; text: Icons.g("x"); color: Theme.dim; font { family: Icons.family; pixelSize: 16 } }
                    MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.open = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) }

            Text {
                visible: !win.ap
                width: parent.width
                text: "Connect your AirPods to change their settings."
                color: Theme.dim
                font { family: Theme.font; pixelSize: 13 }
            }

            Row {
                visible: !!win.ap
                width: parent.width
                spacing: 44
                readonly property real colWidth: (width - spacing) / 2

                Column {
                    width: parent.colWidth
                    spacing: 4
                    MenuHeader { width: parent.width; title: "Noise control" }
                    SettingLevel {
                        width: parent.width
                        title: "Adaptive noise level"
                        desc: "In Adaptive mode: how much of the noise around you gets through."
                        lowText: "Less"; highText: "More"
                        value: win.values.adaptiveLevel || 0
                        onPicked: v => win.setValue("adaptiveLevel", v)
                    }
                    SettingToggle {
                        width: parent.width
                        title: "Conversation Awareness"
                        desc: "Lowers the volume and lets voices through when you start talking."
                        checked: !!win.values.conversation
                        onPicked: v => win.setValue("conversation", v)
                    }
                    SettingToggle {
                        width: parent.width
                        title: "One-Bud ANC"
                        desc: "Keeps noise cancelling on when only one AirPod is in your ear."
                        checked: !!win.values.oneBudAnc
                        onPicked: v => win.setValue("oneBudAnc", v)
                    }
                    SettingToggle {
                        width: parent.width
                        title: "Personalized Volume"
                        desc: "Adjusts the volume over time to your surroundings and how you listen."
                        checked: !!win.values.personalVolume
                        onPicked: v => win.setValue("personalVolume", v)
                    }
                    Item { width: 1; height: 12 }
                    MenuHeader { width: parent.width; title: "Case" }
                    SettingLevel {
                        width: parent.width
                        title: "Case sound volume"
                        desc: "The chime the case plays when it starts charging or you open it."
                        value: win.values.caseVolume || 0
                        onPicked: v => win.setValue("caseVolume", v)
                    }
                }

                Column {
                    width: parent.colWidth
                    spacing: 4
                    MenuHeader { width: parent.width; title: "Stem controls" }
                    SettingToggle {
                        width: parent.width
                        title: "Swipe for volume"
                        desc: "Swipe up or down on the stem to change the volume."
                        checked: !!win.values.swipeVolume
                        onPicked: v => win.setValue("swipeVolume", v)
                    }
                    SettingChoice {
                        width: parent.width
                        title: "Press speed"
                        desc: "How quickly you need to press twice or three times in a row."
                        options: ["Default", "Slower", "Slowest"]
                        current: win.values.pressSpeed || 0
                        onPicked: v => win.setValue("pressSpeed", v)
                    }
                    SettingChoice {
                        width: parent.width
                        title: "Press and hold duration"
                        desc: "How long to hold the stem to switch the listening mode."
                        options: ["Default", "Shorter", "Shortest"]
                        current: win.values.holdDuration || 0
                        onPicked: v => win.setValue("holdDuration", v)
                    }
                    Item { width: 1; height: 12 }
                    MenuHeader { width: parent.width; title: "Automatic pause" }
                    SettingToggle {
                        width: parent.width
                        title: "Ear detection"
                        desc: "Pauses when you take an AirPod out and resumes when you put it back."
                        checked: win.values.earDetection !== false
                        onPicked: v => win.setValue("earDetection", v)
                    }
                    SettingToggle {
                        width: parent.width
                        title: "Sleep detection"
                        desc: "Pauses the music when the AirPods notice you have fallen asleep."
                        checked: !!win.values.sleepDetection
                        onPicked: v => win.setValue("sleepDetection", v)
                    }
                }
            }
        }
    }
}
