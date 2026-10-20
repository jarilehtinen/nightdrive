import QtQuick

// A colour setting: the title, swatches to pick from (`presets`: [[hex, name], …]), the hex value to type your own
// (Enter, or as soon as six digits are in), and a spectrum under the pipette: saturation and brightness in the square,
// hue in the strip, applied when the mouse lets go. picked(hex) as "#rrggbb"; the owner sets `value`.
// (plugins/README.md › Settings windows)
Column {
    id: cp
    property string title: ""
    property string value: ""
    property var presets: []        // [[hex, name], …]
    property int labelWidth: 78     // the title in front of the swatches
    property bool expanded: false
    property real hue: 0; property real sat: 0; property real val: 0
    property bool dragging: false
    readonly property string preview: String(Qt.hsva(hue, sat, val, 1))
    signal picked(string hex)
    onValueChanged: hex.text = value
    onPreviewChanged: if (dragging) hex.text = preview
    function openSpectrum() {
        const c = Qt.color(value || "#000000")
        hue = Math.max(0, c.hsvHue); sat = c.hsvSaturation; val = c.hsvValue
        expanded = !expanded
    }
    topPadding: 4; bottomPadding: 4
    Row {
        width: parent.width
        height: 30
        spacing: 8
        Text {
            width: cp.labelWidth + 4
            anchors.verticalCenter: parent.verticalCenter
            text: cp.title; color: Theme.text; font { family: Theme.font; pixelSize: 13 }
        }
        Repeater {
            model: cp.presets
            Rectangle {
                required property var modelData
                readonly property bool on: cp.value === modelData[0]
                width: 22; height: 22; radius: 11
                anchors.verticalCenter: parent.verticalCenter
                color: modelData[0]
                // outlined: a swatch as dark as the panel would vanish
                border.width: on ? 2 : 1
                border.color: on ? Theme.accent : Theme.dim
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cp.picked(parent.modelData[0]) }
            }
        }
        Item { width: 6; height: 1 }
        Rectangle {
            width: 82; height: 28; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(1, 1, 1, 0.05)
            border.width: hex.activeFocus ? 1 : 0
            border.color: Theme.primary
            TextInput {
                id: hex
                anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                verticalAlignment: TextInput.AlignVCenter
                text: cp.value
                color: Theme.text
                selectByMouse: true
                maximumLength: 7
                font { family: Theme.font; pixelSize: 13 }
                validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{0,6}/ }
                function send() {
                    const h = (text.startsWith("#") ? text : "#" + text).toLowerCase()
                    if (h.length === 7 && h !== cp.value) cp.picked(h)
                }
                onTextEdited: if (text.replace("#", "").length === 6) send()
                onAccepted: send()
            }
        }
        Rectangle {   // the spectrum
            width: 28; height: 28; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            color: cp.expanded ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, pipArea.containsMouse ? 0.10 : 0.05)
            Text { anchors.centerIn: parent; text: Icons.g("pipette"); color: cp.expanded ? Theme.accent : Theme.dim; font { family: Icons.family; pixelSize: 14 } }
            MouseArea { id: pipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cp.openSpectrum() }
        }
    }
    Item {
        visible: cp.expanded
        width: parent.width; height: 150
        Rectangle {
            id: sv
            x: cp.labelWidth + 12
            width: parent.width - x - 40; height: 140; y: 6
            radius: 4
            color: Qt.hsva(cp.hue, 1, 1, 1)
            Rectangle {
                anchors.fill: parent; radius: 4
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#ffffffff" }
                    GradientStop { position: 1; color: "#00ffffff" }
                }
            }
            Rectangle {
                anchors.fill: parent; radius: 4
                gradient: Gradient {
                    GradientStop { position: 0; color: "#00000000" }
                    GradientStop { position: 1; color: "#ff000000" }
                }
            }
            Rectangle {   // the knob
                x: cp.sat * sv.width - 7; y: (1 - cp.val) * sv.height - 7
                width: 14; height: 14; radius: 7
                color: "transparent"
                border { width: 2; color: cp.val > 0.5 && cp.sat < 0.5 ? "black" : "white" }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                preventStealing: true      // a drag here picks a colour, it doesn't scroll the window
                function at(m) {
                    cp.sat = Math.min(1, Math.max(0, m.x / width))
                    cp.val = Math.min(1, Math.max(0, 1 - m.y / height))
                }
                onPressed: m => { cp.dragging = true; at(m) }
                onPositionChanged: m => at(m)
                onReleased: { cp.dragging = false; cp.picked(cp.preview) }
            }
        }
        Rectangle {
            id: hueStrip
            anchors { left: sv.right; leftMargin: 12; top: sv.top }
            width: 22; height: sv.height; radius: 4
            gradient: Gradient {
                GradientStop { position: 0 / 6; color: "#ff0000" }
                GradientStop { position: 1 / 6; color: "#ffff00" }
                GradientStop { position: 2 / 6; color: "#00ff00" }
                GradientStop { position: 3 / 6; color: "#00ffff" }
                GradientStop { position: 4 / 6; color: "#0000ff" }
                GradientStop { position: 5 / 6; color: "#ff00ff" }
                GradientStop { position: 6 / 6; color: "#ff0000" }
            }
            Rectangle {
                y: cp.hue * hueStrip.height - 2
                width: parent.width; height: 4; radius: 2
                color: "white"
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                function at(m) { cp.hue = Math.min(0.999, Math.max(0, m.y / height)) }
                onPressed: m => { cp.dragging = true; at(m) }
                onPositionChanged: m => at(m)
                onReleased: { cp.dragging = false; cp.picked(cp.preview) }
            }
        }
    }
}
