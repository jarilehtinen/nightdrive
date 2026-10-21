import QtQuick

// A battery meter row: label, bar, percentage and a short status (Headphones menu: AirPods per pod and case, other headphones one bar).
// Charging = green with a bolt, under 20 % = red; stale (the last known level, e.g. the AirPods case with no pod in it) = faded.
Item {
    id: b
    property string label: ""          // empty: no label column
    property int labelWidth: 44
    property int level: 0
    property bool charging: false
    property bool stale: false
    property string status: ""         // "in ear", "in case" …
    property int fontSize: 13
    readonly property color tone: charging ? Theme.ok : level < 20 && !stale ? Theme.danger : Theme.accent

    height: 20
    Text {
        id: lbl
        visible: b.label !== ""
        width: visible ? b.labelWidth : 0
        anchors.verticalCenter: parent.verticalCenter
        text: b.label
        color: Theme.text
        font { family: Theme.font; pixelSize: b.fontSize }
    }
    BatteryShape {   // a battery, not a slider's track: the Max volume slider sits in the same menu
        id: track
        anchors { left: lbl.right; leftMargin: lbl.visible ? 10 : 0; right: pct.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        height: 14
        level: b.level
        color: b.tone
        fillOpacity: b.stale ? 0.4 : 1
    }
    Text {
        id: pct
        anchors { right: st.left; rightMargin: st.width > 0 ? 10 : 0; verticalCenter: parent.verticalCenter }
        width: 38
        horizontalAlignment: Text.AlignRight
        text: b.level + "%"
        color: b.stale ? Theme.dim : b.level < 20 && !b.charging ? Theme.danger : Theme.text
        font { family: Theme.font; pixelSize: b.fontSize }
    }
    Row {
        id: st
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        // A column for the status only when there is one (AirPods: every row has one, so the bars line up); without one
        // (other headphones' single bar) the bar reaches the percentage at the right edge
        width: b.status !== "" || b.charging ? 64 : 0
        spacing: 4
        Text {
            visible: b.charging
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.g("zap")
            color: Theme.ok
            font { family: Icons.family; pixelSize: b.fontSize - 1 }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: b.status
            color: b.charging ? Theme.ok : b.level < 20 && !b.stale ? Theme.danger : Theme.dim
            font { family: Theme.font; pixelSize: b.fontSize - 2 }
        }
    }
}
