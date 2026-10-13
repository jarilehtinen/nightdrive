// Quickshell – menus for the top bar icons.
// Waybar opens a menu with:  qs ipc call menu toggleAt <volume|headphones|wifi|bluetooth|battery|tailscale|power|claude|calendar|system|…> <x>
// (x = cursor position; without x:  qs ipc call menu toggle <name>  opens the menu at the right edge)
// Menus live in <Name>Menu.qml files; shared parts: Theme, Icons, Sh, MenuRow, MenuHeader, Slider.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property string current: ""
    property real anchorX: -1          // icon's horizontal coordinate (logical px); -1 = right edge

    // --- Keyboard navigation (⌘⇧Space): ←/→ switch menu, ↑/↓ select a row, Enter activates, Esc closes ---
    // top bar order from the left (keep in the same order as modules-right in waybar/config.jsonc); the headphones icon
    // is only shown while Bluetooth headphones are connected
    property bool headphones: false
    readonly property var orderStart: localMenus.concat(["deck", "claude", "system", "tailscale", "bluetooth", "wifi", "volume"])
    readonly property var orderEnd: ["battery", "calendar", "notifications"]
    readonly property var order: orderStart.concat(headphones ? ["headphones"] : [], orderEnd)
    property bool navMode: false
    // Personal additions from a private overlay (local/, not in the repo): <Name>Menu.qml files become menus at the left end
    // of the bar's icon group (the overlay adds the bar icons itself), LauncherExtension.qml extends the launcher.
    property var localMenus: []
    property bool localLauncher: false
    Sh {
        command: ["ls", Quickshell.shellDir + "/local"]
        running: true
        onResult: text => {
            const files = text.split("\n")
            root.localMenus = files.filter(f => /^[A-Z]\w*Menu\.qml$/.test(f)).map(f => f.charAt(0).toLowerCase() + f.slice(1, -8))
            root.localLauncher = files.indexOf("LauncherExtension.qml") >= 0
        }
    }
    property bool viaSubmap: false     // opened by click/shortcut: ←/→/↑/↓/Enter/Esc come from a Hyprland submap (hypr/bindings.lua: qsmenu), no keyboard focus
    property var navItem: null         // selected row / toggle
    property var xs: ({})              // last clicked positions of the icons (the menu opens below the icon); saved to a file
    readonly property string xsFile: Quickshell.env("HOME") + "/.cache/qs-menu-x.json"

    function submap(name) { Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.submap("' + name + '")']) }
    Component.onCompleted: submap("reset")      // safety net: in case the previous session was left in the submap

    onCurrentChanged: {
        navItem = null
        if (current === "") { navMode = false; viaSubmap = false }
        submap(current !== "" && viaSubmap ? "qsmenu" : "reset")
        // Waybar highlights the open menu's icon (class "open" in the status script): state to a file + refresh signal
        Quickshell.execDetached(["bash", "-c", 'printf %s "$1" > "${XDG_RUNTIME_DIR:-/tmp}/qs-menu"; pkill -RTMIN+8 waybar', "_", current])
    }
    function rememberX(name, x) {
        if (Math.round(xs[name] || -1) === Math.round(x)) return
        const n = Object.assign({}, xs); n[name] = x; xs = n
        Quickshell.execDetached(["bash", "-c", 'mkdir -p "$(dirname "$2")"; printf %s "$1" > "$2"', "_", JSON.stringify(n), xsFile])
    }
    function openNav(i) {
        const n = order.length
        const name = order[((i % n) + n) % n]
        anchorX = xs[name] !== undefined ? xs[name] : -1
        current = name
    }
    property int navStart: 0
    property bool navOpenAfterMeasure: true   // false = only measure and store the icon positions
    function navToggle() {
        if (navMode) { current = ""; return }
        viaSubmap = false
        navMode = true
        navStart = Math.max(0, order.indexOf(current))
        navOpenAfterMeasure = true
        // Measure the icon positions from a screenshot of the bar, so the menu opens at the same spot as when clicking the icon
        if (!posProc.running) posProc.running = true
        keyItem.forceActiveFocus()
    }
    Sh {
        id: posProc
        // First line: whether the headphones icon is in the bar (affects the icon count), second: the positions
        script: 'hp=0; pactl list short sinks | grep -q bluez_output && hp=1; echo $hp
n=(' + root.orderStart.join(" ") + '); ((hp)) && n+=(headphones); n+=(' + root.orderEnd.join(" ") + ')
"$HOME/.config/waybar/scripts/icon-positions" "${n[@]}"'
        onResult: text => {
            root.headphones = text.charAt(0) === "1"
            text = text.slice(2)
            try { root.xs = Object.assign({}, root.xs, JSON.parse(text)) } catch (e) {}
            if (root.navMode && root.navOpenAfterMeasure) { root.openNav(root.navStart); keyItem.forceActiveFocus() }
        }
    }
    function navRows() {
        const out = []
        const walk = it => {
            for (const c of it.children) {
                if (!c.visible) continue
                if (typeof c.navActivate === "function" && c.navEnabled !== false && c.height > 0) out.push(c)
                walk(c)
            }
        }
        if (loader.item) walk(loader.item)
        out.sort((a, b) => a.mapToItem(card, 0, 0).y - b.mapToItem(card, 0, 0).y)
        return out
    }
    function navMove(d) {
        const rows = navRows()
        if (rows.length === 0) return
        let i = rows.indexOf(navItem)
        i = i < 0 ? (d > 0 ? 0 : rows.length - 1) : (i + d + rows.length) % rows.length
        if (navItem) navItem.navSelected = false
        navItem = rows[i]
        navItem.navSelected = true
    }
    function navAct(a) {     // a: left | right | up | down | enter
        if (!navMode) return false
        if (a === "left")       openNav(order.indexOf(current) - 1)
        else if (a === "right") openNav(order.indexOf(current) + 1)
        else if (a === "up")    navMove(-1)
        else if (a === "down")  navMove(1)
        else if (a === "enter") { if (navItem) navItem.navActivate() }
        else if (a === "esc")   current = ""
        else return false
        return true
    }
    function navKey(event) {
        const a = { [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Return]: "enter", [Qt.Key_Enter]: "enter", [Qt.Key_Escape]: "esc" }[event.key]
        if (a && navAct(a)) event.accepted = true
    }
    Sh {
        command: ["cat", root.xsFile]
        running: true
        onResult: text => { try { root.xs = JSON.parse(text) } catch (e) {} }
    }

    IpcHandler {
        target: "menu"
        // toggleAt: x = cursor position at click time (= the icon's position), the menu opens below the icon
        // A menu opened by clicking also enters keyboard mode (Esc closes, arrows/Enter work as with ⌘⇧Space)
        function toggleAt(name: string, x: int): void {
            root.rememberX(name, x); root.anchorX = x
            const opening = root.current !== name
            // The Wifi menu has a password field that needs real keyboard focus: no arrow-key navigation
            root.viaSubmap = opening && name !== "wifi"
            root.navMode = root.viaSubmap
            root.current = opening ? name : ""
            if (root.navMode) {
                // Icon positions for ←/→ navigation (measurement only, doesn't reopen the menu)
                if (Object.keys(root.xs).length < root.order.length && !posProc.running) { root.navOpenAfterMeasure = false; posProc.running = true }
            }
        }
        // toggle: opened by a shortcut (e.g. ⌘Esc -> power). Opens in keyboard mode so Esc closes and arrows/Enter work.
        function toggle(name: string): void {
            root.anchorX = -1
            const opening = root.current !== name
            root.viaSubmap = opening
            root.navMode = opening
            root.current = opening ? name : ""
        }
        function close(): void { root.current = "" }
        function nav(): void { root.navToggle() }
        function navkey(a: string): string { root.navAct(a); return root.current + " | " + (root.navItem ? (root.navItem.label || root.navItem.title || "?") : "-") }   // testing / scripts
    }

    Osd {}

    Picker {}

    Shelf {}

    Launcher {
        extSource: root.localLauncher ? "local/LauncherExtension.qml" : ""
        onOpenMenu: name => { root.anchorX = -1; root.current = name }
    }

    PanelWindow {
        visible: root.current !== ""
        anchors { top: true; bottom: true; left: true; right: true }
        margins { top: Theme.barHeight }   // the top bar stays clickable
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        // Keyboard focus only for the wifi menu (password field): with OnDemand a second click on the top bar
        // was lost until the mouse was moved.
        WlrLayershell.keyboardFocus: root.navMode && !root.viaSubmap ? WlrKeyboardFocus.Exclusive : (root.current === "wifi" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)

        // Clicking outside the menu closes it
        MouseArea { anchors.fill: parent; onClicked: root.current = "" }
        Item { id: keyItem; anchors.fill: parent; focus: true; Keys.onEscapePressed: root.current = ""; Keys.onPressed: event => root.navKey(event) }

        Rectangle {
            id: card
            anchors { top: parent.top; topMargin: 6 }
            width: loader.item && loader.item.preferredWidth ? loader.item.preferredWidth : 320   // a menu can request a wider card
            // Center below the icon, but keep a 10 px margin from the screen edges
            x: root.anchorX < 0 ? parent.width - width - 10
                                : Math.max(10, Math.min(parent.width - width - 10, root.anchorX - width / 2))
            height: loader.item ? loader.item.implicitHeight + 26 : 0   // 10 px top and 16 px bottom margin
            radius: 10
            color: Theme.bg
            border.width: 0   // no border (the dividers inside the menu stay)
            Keys.onEscapePressed: root.current = ""

            MouseArea { anchors.fill: parent }   // a click inside the card doesn't close the menu

            Loader {
                id: loader
                anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16; topMargin: 10 }
                source: root.current === "" ? ""
                      : (root.localMenus.indexOf(root.current) >= 0 ? "local/" : "") + root.current.charAt(0).toUpperCase() + root.current.slice(1) + "Menu.qml"
            }
            Connections {
                target: loader.item
                ignoreUnknownSignals: true
                function onClose() { root.current = "" }
            }
        }
    }
}
