import QtQuick

// A level on a slider, 0 to `to`: picked(v) when the mouse lets go (the value shows while dragging).
// Title and explanation above the slider; with labelWidth the title stands in front of it on one row instead (a
// compact window: ThemeEditor) and the explanation goes under. On the right the value with its unit, or lowText /
// highText at the ends of the slider. (plugins/README.md › Settings windows)
Column {
    id: lv
    property string title: ""
    property string desc: ""
    property real value: 0
    property real to: 100
    property string unit: "%"
    property string lowText: ""
    property string highText: ""
    property int labelWidth: 0
    property real dragging: -1          // 0..1 while held
    readonly property bool inline: labelWidth > 0
    signal picked(int v)
    topPadding: inline ? 4 : 8; bottomPadding: inline ? 4 : 12
    spacing: inline ? 4 : 12
    Column {
        visible: !lv.inline
        width: parent.width
        spacing: 4
        Text { width: parent.width; text: lv.title; color: Theme.text; font { family: Theme.font; pixelSize: 14 } }
        Text {
            visible: lv.desc !== ""
            width: parent.width
            text: lv.desc
            wrapMode: Text.Wrap
            lineHeight: 1.15
            color: Theme.dim
            font { family: Theme.font; pixelSize: 12 }
        }
    }
    Row {
        width: parent.width
        height: lv.inline ? 30 : implicitHeight
        spacing: 12
        Text {
            visible: lv.inline
            width: lv.labelWidth
            anchors.verticalCenter: parent.verticalCenter
            text: lv.title; color: Theme.text; font { family: Theme.font; pixelSize: 13 }
        }
        Text { id: lo; visible: lv.lowText !== ""; text: lv.lowText; color: Theme.dim; anchors.verticalCenter: parent.verticalCenter; font { family: Theme.font; pixelSize: 11 } }
        Slider {
            width: parent.width - (lv.inline ? lv.labelWidth + 12 : 0) - (lo.visible ? lo.width + 12 : 0) - hi.width - 12
            anchors.verticalCenter: parent.verticalCenter
            trackColor: Qt.rgba(1, 1, 1, 0.1)
            value: lv.dragging >= 0 ? lv.dragging : lv.value / lv.to
            onMoved: v => lv.dragging = v
            onPressedChanged: if (!pressed && lv.dragging >= 0) { lv.picked(Math.round(lv.dragging * lv.to)); lv.dragging = -1 }
        }
        Text {
            id: hi
            width: lv.highText !== "" ? implicitWidth : 52
            horizontalAlignment: Text.AlignRight
            text: lv.highText !== "" ? lv.highText
                : Math.round(lv.dragging >= 0 ? lv.dragging * lv.to : lv.value) + (lv.unit === "%" ? "%" : " " + lv.unit)
            color: lv.highText !== "" ? Theme.dim : Theme.text
            anchors.verticalCenter: parent.verticalCenter
            font { family: Theme.font; pixelSize: lv.highText !== "" ? 11 : 13 }
        }
    }
    Text {
        visible: lv.inline && lv.desc !== ""
        width: parent.width
        text: lv.desc
        wrapMode: Text.Wrap
        color: Theme.dim
        font { family: Theme.font; pixelSize: 11 }
    }
}
