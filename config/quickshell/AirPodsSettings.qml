import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// AirPods settings in the middle of the screen, over everything: the AirPods' own settings (each with a short explanation)
// and Nightdrive's ear detection. Opened by the headphones menu and the launcher (Settings › Headphones): qs ipc call airpods open
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

    // ---- the parts: an on/off setting, a choice of three, a level ----
    component Switch: Rectangle {
        property bool checked: false
        signal toggled()
        width: 34; height: 20; radius: 10
        color: checked ? Theme.accent : Theme.border
        Rectangle {
            width: 14; height: 14; radius: 7; y: 3
            x: parent.checked ? 17 : 3
            color: parent.checked ? Theme.bg : Theme.text
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        MouseArea { cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: parent.toggled() }
    }
    component Title: Column {
        property string title: ""
        property string desc: ""
        spacing: 4
        Text { width: parent.width; text: parent.title; color: Theme.text; font { family: Theme.font; pixelSize: 14 } }
        Text {
            width: parent.width
            text: parent.desc
            wrapMode: Text.Wrap
            lineHeight: 1.15
            color: Theme.dim
            font { family: Theme.font; pixelSize: 12 }
        }
    }
    component Toggle: Item {
        id: tg
        property string title: ""
        property string desc: ""
        property bool checked: false
        signal picked(bool v)
        height: Math.max(t.implicitHeight, 20) + 16
        Title { id: t; y: 8; width: parent.width - 50; title: tg.title; desc: tg.desc }
        Switch { anchors.right: parent.right; y: 10; checked: tg.checked; onToggled: tg.picked(!tg.checked) }
    }
    component Choice: Column {
        id: ch
        property string title: ""
        property string desc: ""
        property var options: []
        property int current: 0
        signal picked(int v)
        topPadding: 8; bottomPadding: 8
        spacing: 10
        Title { width: parent.width; title: ch.title; desc: ch.desc }
        Rectangle {
            width: parent.width; height: 36; radius: 8
            color: Qt.rgba(1, 1, 1, 0.05)
            Row {
                anchors { fill: parent; margins: 3 }
                spacing: 4
                Repeater {
                    model: ch.options
                    Rectangle {
                        required property string modelData
                        required property int index
                        readonly property bool on: ch.current === index
                        width: (parent.width - 8) / 3; height: parent.height; radius: 6
                        // the theme colour, stronger than a selected row: the choice has to read at a glance
                        color: on ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.32) : area.containsMouse ? Theme.hover : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: parent.on ? Qt.lighter(Theme.accent, 1.08) : Theme.dim
                            font { family: Theme.font; pixelSize: 12; weight: parent.on ? Font.Medium : Font.Normal }
                        }
                        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.picked(parent.index) }
                    }
                }
            }
        }
    }
    component Level: Column {
        id: lv
        property string title: ""
        property string desc: ""
        property int value: 0           // 0–100
        property string lowText: ""     // labels at the ends of the slider; empty: the value on the right
        property string highText: ""
        property real dragging: -1
        signal picked(int v)
        topPadding: 8; bottomPadding: 12
        spacing: 12
        Title { width: parent.width; title: lv.title; desc: lv.desc }
        Row {
            width: parent.width
            spacing: 12
            Text { id: lo; text: lv.lowText; color: Theme.dim; anchors.verticalCenter: parent.verticalCenter; font { family: Theme.font; pixelSize: 11 } }
            Slider {
                width: parent.width - lo.width - hi.width - 24
                anchors.verticalCenter: parent.verticalCenter
                trackColor: Qt.rgba(1, 1, 1, 0.1)
                value: lv.dragging >= 0 ? lv.dragging : lv.value / 100
                onMoved: v => lv.dragging = v
                onPressedChanged: if (!pressed && lv.dragging >= 0) { lv.picked(Math.round(lv.dragging * 100)); lv.dragging = -1 }
            }
            Text {
                id: hi
                width: lv.highText !== "" ? implicitWidth : 36
                horizontalAlignment: Text.AlignRight
                text: lv.highText !== "" ? lv.highText : Math.round(lv.dragging >= 0 ? lv.dragging * 100 : lv.value) + "%"
                color: lv.highText !== "" ? Theme.dim : Theme.text
                anchors.verticalCenter: parent.verticalCenter
                font { family: Theme.font; pixelSize: lv.highText !== "" ? 11 : 13 }
            }
        }
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
                    color: closeArea.containsMouse ? Theme.hover : Qt.rgba(1, 1, 1, 0.05)
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
                    Level {
                        width: parent.width
                        title: "Adaptive noise level"
                        desc: "In Adaptive mode: how much of the noise around you gets through."
                        lowText: "Less"; highText: "More"
                        value: win.values.adaptiveLevel || 0
                        onPicked: v => win.setValue("adaptiveLevel", v)
                    }
                    Toggle {
                        width: parent.width
                        title: "Conversation Awareness"
                        desc: "Lowers the volume and lets voices through when you start talking."
                        checked: !!win.values.conversation
                        onPicked: v => win.setValue("conversation", v)
                    }
                    Toggle {
                        width: parent.width
                        title: "One-Bud ANC"
                        desc: "Keeps noise cancelling on when only one AirPod is in your ear."
                        checked: !!win.values.oneBudAnc
                        onPicked: v => win.setValue("oneBudAnc", v)
                    }
                    Toggle {
                        width: parent.width
                        title: "Personalized Volume"
                        desc: "Adjusts the volume over time to your surroundings and how you listen."
                        checked: !!win.values.personalVolume
                        onPicked: v => win.setValue("personalVolume", v)
                    }
                    Item { width: 1; height: 12 }
                    MenuHeader { width: parent.width; title: "Case" }
                    Level {
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
                    Toggle {
                        width: parent.width
                        title: "Swipe for volume"
                        desc: "Swipe up or down on the stem to change the volume."
                        checked: !!win.values.swipeVolume
                        onPicked: v => win.setValue("swipeVolume", v)
                    }
                    Choice {
                        width: parent.width
                        title: "Press speed"
                        desc: "How quickly you need to press twice or three times in a row."
                        options: ["Default", "Slower", "Slowest"]
                        current: win.values.pressSpeed || 0
                        onPicked: v => win.setValue("pressSpeed", v)
                    }
                    Choice {
                        width: parent.width
                        title: "Press and hold duration"
                        desc: "How long to hold the stem to switch the listening mode."
                        options: ["Default", "Shorter", "Shortest"]
                        current: win.values.holdDuration || 0
                        onPicked: v => win.setValue("holdDuration", v)
                    }
                    Item { width: 1; height: 12 }
                    MenuHeader { width: parent.width; title: "Automatic pause" }
                    Toggle {
                        width: parent.width
                        title: "Ear detection"
                        desc: "Pauses when you take an AirPod out and resumes when you put it back."
                        checked: win.values.earDetection !== false
                        onPicked: v => win.setValue("earDetection", v)
                    }
                    Toggle {
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
