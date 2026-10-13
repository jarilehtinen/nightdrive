import QtQuick

// One module in the top bar: an icon and/or a text in a rounded box (the box lights up while its menu is open).
// The icon is an SVG in a size × size square and the text is centred by its digits, both independently of each
// other: adjust.conf's y moves only that part. Positions are snapped to whole device pixels.
Item {
    id: mod
    required property var def             // the module's entry in modules.jsonc
    property bool open: false               // its menu is open
    property bool hasMenu: false
    property real dpr: 1
    signal leftClicked(real centerX)

    readonly property string name: def.name
    readonly property var st: TopBar.states[name] || null
    readonly property string icon: st && st.icon ? st.icon : ""
    readonly property string label: st && st.text ? st.text : ""
    readonly property string cls: st && st.class ? st.class : ""
    readonly property bool active: cls === "active"
    visible: icon !== "" || label !== ""

    readonly property var isz: TopBar.size(name)
    readonly property int pad: 8
    readonly property int gap: 5
    readonly property color fg: open || active ? TopBar.c("hlFg")
                              : cls === "off" ? TopBar.c("off")
                              : cls === "warning" ? Theme.warning
                              : cls === "critical" ? Theme.danger
                              : TopBar.c("fg")
    function snap(v) { return Math.round(v * dpr) / dpr }

    height: 27
    width: visible ? Math.max(icon && !label ? 34 : 0, pad + (icon ? isz.size : 0) + (icon && label ? gap : 0) + (label ? txt.implicitWidth : 0) + pad) : 0

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: mod.open ? TopBar.c("hlBg") : mod.active ? TopBar.c("actBg") : "transparent"
    }

    Item {
        anchors.fill: parent
        opacity: mod.cls === "stale" ? 0.6 : 1

        Image {
            id: img
            visible: mod.icon !== ""
            width: mod.isz.size; height: mod.isz.size
            x: mod.snap(mod.label ? mod.pad : (mod.width - width) / 2)
            y: mod.snap((mod.height - height) / 2 + mod.isz.y)
            sourceSize: Qt.size(Math.ceil(width * mod.dpr), Math.ceil(height * mod.dpr))
            source: TopBar.iconUrl(mod.icon, mod.fg)
            opacity: mod.fg.a
            smooth: true
            cache: false
        }

        BarText {
            id: txt
            visible: mod.label !== ""
            text: mod.label
            color: mod.fg
            dpr: mod.dpr
            x: mod.snap(mod.icon ? img.x + img.width + mod.gap : (mod.width - implicitWidth) / 2)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) { if (mod.hasMenu) mod.leftClicked(mod.mapToItem(null, mod.width / 2, 0).x) }
            else if (mouse.button === Qt.RightButton && mod.def.right) TopBar.run(mod.def.right, mod.name)
            else if (mouse.button === Qt.MiddleButton && mod.def.middle) TopBar.run(mod.def.middle, mod.name)
        }
    }
}
