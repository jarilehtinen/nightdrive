import QtQuick
import Quickshell

// Wifi: on/off, network list, connecting (asks for a password for new secured networks).
// Uses nmcli (Quickshell's Networking module returns no data on this machine).
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 8

    property bool wifiOn: LastState.wifi
    onWifiOnChanged: LastState.wifi = wifiOn
    property var nets: []            // [{ ssid, signal, secure, active, known }]
    property var knownSet: ({})
    property string connecting: ""
    property string askFor: ""       // network whose password is being asked for
    property string message: ""
    signal close()

    // nmcli -t separates fields with ':' and escapes a ':' inside a field as \:
    function splitTerse(line) {
        const out = []; let cur = ""
        for (let i = 0; i < line.length; i++) {
            const c = line[i]
            if (c === "\\" && i + 1 < line.length) cur += line[++i]
            else if (c === ":") { out.push(cur); cur = "" }
            else cur += c
        }
        out.push(cur)
        return out
    }
    function sigIcon(s) { return s >= 75 ? "wifi" : s >= 50 ? "wifi-high" : s >= 25 ? "wifi-low" : "wifi-zero" }

    readonly property var activeNet: nets.find(n => n.active) || null
    readonly property var otherNets: nets.filter(n => !n.active)

    // Public IP (external service api.ipify.org): fetched when the menu opens, every minute and when the connected network changes
    property string publicIp: ""
    property bool ipFailed: false
    readonly property string activeSsid: activeNet ? activeNet.ssid : ""
    onActiveSsidChanged: { publicIp = ""; ipFailed = false; if (activeSsid !== "") ipProc.running = true }
    Timer { interval: 60000; repeat: true; running: m.activeSsid !== ""; onTriggered: ipProc.running = true }
    Sh {
        id: ipProc
        script: 'curl -s --max-time 5 https://api.ipify.org'
        onResult: text => {
            const ip = text.replace(/\s+/g, "")
            if (ipProc.exitCode === 0 && /^[0-9a-fA-F:.]{3,45}$/.test(ip)) { m.publicIp = ip; m.ipFailed = false }
            else if (m.publicIp === "") m.ipFailed = true
        }
    }

    // Live throughput: read the wifi interface's byte counters every second
    property real rxRate: 0
    property real txRate: 0
    property real lastRx: -1
    property real lastTx: -1
    property real lastT: 0
    function fmtRate(b) {
        const bits = b * 8
        if (bits >= 1e9) return (bits / 1e9).toFixed(2) + " Gb/s"
        if (bits >= 1e6) return (bits / 1e6).toFixed(1) + " Mb/s"
        if (bits >= 1e3) return Math.round(bits / 1e3) + " kb/s"
        return Math.round(bits) + " b/s"
    }
    Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: rateProc.running = true }
    Sh {
        id: rateProc
        script: 'for d in /sys/class/net/*/wireless; do i=${d%/wireless}; echo "$(cat $i/statistics/rx_bytes) $(cat $i/statistics/tx_bytes)"; break; done'
        onResult: text => {
            const f = text.trim().split(/\s+/).map(Number)
            if (f.length < 2 || isNaN(f[0])) return
            const now = Date.now()
            if (m.lastRx >= 0 && now > m.lastT) {
                const dt = (now - m.lastT) / 1000
                m.rxRate = Math.max(0, (f[0] - m.lastRx) / dt)
                m.txRate = Math.max(0, (f[1] - m.lastTx) / dt)
            }
            m.lastRx = f[0]; m.lastTx = f[1]; m.lastT = now
        }
    }

    function refresh() { radioProc.running = true; knownProc.running = true; listProc.running = true }
    function rescan() { Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]) }
    Component.onCompleted: { refresh(); rescan() }

    Timer { interval: 3000; repeat: true; running: true; onTriggered: m.refresh() }
    Timer { interval: 10000; repeat: true; running: true; onTriggered: m.rescan() }

    function connectTo(n, password) {
        m.message = ""
        m.connecting = n.ssid
        connectProc.environment = { "SSID": n.ssid, "PW": password || "" }
        connectProc.running = true
    }
    function activate(n) {
        if (m.connecting !== "") return
        if (n.active) {
            m.connecting = n.ssid
            disconnectProc.environment = { "SSID": n.ssid }
            disconnectProc.running = true
        } else if (n.secure && !n.known) {
            m.askFor = (m.askFor === n.ssid) ? "" : n.ssid
        } else {
            connectTo(n, "")
        }
    }

    Sh {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        onResult: text => m.wifiOn = text.trim() === "enabled"
    }
    Sh {
        id: knownProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        onResult: text => {
            const set = {}
            for (const line of text.split("\n")) {
                const f = m.splitTerse(line)
                if (f.length >= 2 && f[1] === "802-11-wireless") set[f[0]] = true
            }
            m.knownSet = set
        }
    }
    Sh {
        id: listProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        onResult: text => {
            const by = {}
            for (const line of text.split("\n")) {
                if (!line) continue
                const f = m.splitTerse(line)
                if (f.length < 4 || f[1] === "") continue
                const n = { ssid: f[1], signal: parseInt(f[2]) || 0, secure: f[3] !== "" && f[3] !== "--", active: f[0] === "*", known: !!m.knownSet[f[1]] }
                const old = by[n.ssid]
                if (!old || n.active || (!old.active && n.signal > old.signal)) by[n.ssid] = n
            }
            const arr = Object.values(by)
            arr.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
            m.nets = arr
        }
    }
    Sh {
        id: connectProc
        script: 'if [ -n "$PW" ]; then nmcli --wait 20 device wifi connect "$SSID" password "$PW"; else nmcli --wait 20 device wifi connect "$SSID"; fi'
        onResult: text => {
            m.connecting = ""
            if (connectProc.exitCode !== 0) {
                const lines = text.trim().split("\n")
                m.message = lines[lines.length - 1].replace(/^Error:\s*/, "")
            } else {
                m.message = ""; m.askFor = ""
            }
            m.refresh()
        }
    }
    Sh {
        id: disconnectProc
        script: 'nmcli connection down id "$SSID"'
        onResult: text => { m.connecting = ""; m.refresh() }
    }

    MenuHeader {
        width: parent.width
        title: "Wifi"
        showToggle: true
        checked: m.wifiOn
        onToggled: {
            m.wifiOn = !m.wifiOn
            Quickshell.execDetached(["nmcli", "radio", "wifi", m.wifiOn ? "on" : "off"])
            if (!m.wifiOn) m.nets = []
        }
    }

    // Connected network at the top, with throughput and public IP below it
    MenuRow {
        visible: m.wifiOn && m.activeNet !== null
        width: parent.width
        icon: m.sigIcon(m.activeNet ? m.activeNet.signal : 0)
        label: m.activeSsid
        active: true
        detail: m.connecting === m.activeSsid ? "…" : ""
        checkIcon: "check"
        onClicked: m.activate(m.activeNet)
    }
    Row {
        visible: m.wifiOn && m.activeNet !== null
        leftPadding: 10
        spacing: 18
        Row {
            spacing: 6
            Text { text: Icons.g("arrow-down"); color: Theme.accent; font { family: Icons.family; pixelSize: 13 } anchors.verticalCenter: parent.verticalCenter }
            Text { text: m.fmtRate(m.rxRate); color: Theme.text; font { family: Theme.font; pixelSize: 12 } }
        }
        Row {
            spacing: 6
            Text { text: Icons.g("arrow-up"); color: Theme.accent; font { family: Icons.family; pixelSize: 13 } anchors.verticalCenter: parent.verticalCenter }
            Text { text: m.fmtRate(m.txRate); color: Theme.text; font { family: Theme.font; pixelSize: 12 } }
        }
    }
    Row {
        visible: m.wifiOn && m.activeNet !== null
        leftPadding: 10
        spacing: 6
        Text { text: Icons.g("globe"); color: Theme.accent; font { family: Icons.family; pixelSize: 13 } anchors.verticalCenter: parent.verticalCenter }
        Text { text: m.publicIp !== "" ? m.publicIp : (m.ipFailed ? "public IP unavailable" : "…"); color: m.publicIp !== "" ? Theme.text : Theme.dim; font { family: Theme.font; pixelSize: 12 } }
    }

    Text {
        visible: m.wifiOn && m.nets.length === 0
        text: "Searching for networks…"
        color: Theme.dim
        font { family: Theme.font; pixelSize: 12 }
    }
    Text {
        visible: !m.wifiOn
        text: "Wifi is off"
        color: Theme.dim
        font { family: Theme.font; pixelSize: 12 }
    }

    Divider { visible: m.wifiOn && m.activeNet !== null && m.otherNets.length > 0 }
    Text {
        visible: m.wifiOn && m.otherNets.length > 0
        text: m.activeNet ? "OTHER NETWORKS" : "NETWORKS"
        color: Theme.primary
        font { family: Theme.font; pixelSize: 11; letterSpacing: 0.6 }
    }

    Column {
        width: parent.width
        spacing: 2
        Repeater {
            model: m.otherNets.slice(0, 8)
            delegate: Column {
                id: item
                required property var modelData
                width: parent.width
                spacing: 4

                MenuRow {
                    width: parent.width
                    icon: m.sigIcon(item.modelData.signal)
                    label: item.modelData.ssid
                    active: item.modelData.active
                    detail: m.connecting === item.modelData.ssid ? "…" : (item.modelData.known && !item.modelData.active ? "saved" : "")
                    checkIcon: item.modelData.active ? "check" : (item.modelData.secure ? "lock" : "")
                    onClicked: m.activate(item.modelData)
                }

                // Password field for a new secured network
                Rectangle {
                    visible: m.askFor === item.modelData.ssid
                    width: parent.width
                    height: visible ? 36 : 0
                    radius: 8
                    color: Theme.hover
                    border.color: Theme.border
                    TextInput {
                        id: pw
                        anchors { left: parent.left; right: go.left; leftMargin: 12; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        echoMode: TextInput.Password
                        color: Theme.text
                        selectionColor: Theme.sel
                        font { family: Theme.font; pixelSize: 13 }
                        focus: parent.visible
                        onVisibleChanged: if (visible) forceActiveFocus()
                        onAccepted: if (text !== "") m.connectTo(item.modelData, text)
                        Text {
                            visible: pw.text === ""
                            text: "Password"
                            color: Theme.dim
                            font: pw.font
                        }
                    }
                    Text {
                        id: go
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: "Connect"
                        color: pw.text === "" ? Theme.dim : Theme.accent
                        font { family: Theme.font; pixelSize: 12 }
                        MouseArea { cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: if (pw.text !== "") m.connectTo(item.modelData, pw.text) }
                    }
                }
            }
        }
    }

    Text {
        visible: m.message !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: m.message
        color: Theme.danger
        font { family: Theme.font; pixelSize: 12 }
    }

    Divider {}
    MenuRow {
        width: parent.width
        icon: "settings"
        action: true
        label: "Network settings…"
        onClicked: { Quickshell.execDetached(["kitty", "--class", "floating-tui", "-e", "nmtui"]); m.close() }
    }
}
