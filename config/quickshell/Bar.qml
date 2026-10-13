import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// The top bar on every screen: workspaces on the left, the modules (TopBar, ~/.config/topbar/modules.jsonc) on the right.
// A left click opens the module's menu (shell.qml); the open menu's module is highlighted.
Variants {
    id: bar
    model: Quickshell.screens
    property string current: ""         // the open menu
    property var menus: []              // menus that exist (<Name>Menu.qml)
    signal menuClicked(string menu, real x, var screen)

    function menuOf(def) {
        const m = def.menu !== undefined ? def.menu : def.name
        return menus.indexOf(m) >= 0 ? m : ""
    }
    // Visible modules with a menu, left to right (keyboard navigation), and an icon's centre on the first screen
    function navOrder() {
        const w = instances[0]
        return w ? w.modules().filter(m => m.visible && m.hasMenu).map(m => menuOf(m.def)) : []
    }
    function xOf(menu) {
        const w = instances[0]
        const m = w ? w.modules().find(m => m.visible && menuOf(m.def) === menu) : null
        return m ? m.mapToItem(null, m.width / 2, 0).x : -1
    }

    delegate: PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: Theme.barHeight
        color: TopBar.c("bg")
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "nightdrive-bar"
        readonly property real dpr: modelData.devicePixelRatio || 1
        function modules() { const out = []; for (let i = 0; i < rep.count; i++) out.push(rep.itemAt(i)); return out }

        // Workspaces 1–5 always, others while they exist; the screen's active one highlighted, empty ones dimmed.
        // Number size and position: the `workspaces` row in adjust.conf.
        Row {
            x: 10; anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: {
                    const ids = [1, 2, 3, 4, 5]
                    for (const w of Hyprland.workspaces.values) if (w.id > 0 && ids.indexOf(w.id) < 0) ids.push(w.id)
                    return ids.sort((a, b) => a - b)
                }
                Rectangle {
                    id: ws
                    required property int modelData
                    readonly property var hw: Hyprland.workspaces.values.find(w => w.id === modelData) || null
                    readonly property bool active: { const m = Hyprland.monitorFor(win.modelData); return !!m && !!m.activeWorkspace && m.activeWorkspace.id === modelData }
                    width: num.implicitWidth + 20; height: 27; radius: 8
                    color: active ? TopBar.c("wsBg") : "transparent"
                    BarText {
                        id: num
                        element: "workspaces"
                        dpr: win.dpr
                        x: Math.round((parent.width - implicitWidth) / 2 * win.dpr) / win.dpr
                        text: ws.modelData
                        color: ws.active ? TopBar.c("hlFg") : ws.hw && ws.hw.toplevels.values.length > 0 ? TopBar.c("dim") : TopBar.c("off")
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + ws.modelData + " })"])
                    }
                }
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 3
            Repeater {
                id: rep
                model: TopBar.modules
                BarModule {
                    required property var modelData
                    def: modelData
                    dpr: win.dpr
                    hasMenu: bar.menuOf(modelData) !== ""
                    open: hasMenu && bar.current === bar.menuOf(modelData)
                    onLeftClicked: x => bar.menuClicked(bar.menuOf(modelData), x, win.modelData)
                }
            }
        }
    }
}
