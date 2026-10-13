import QtQuick
import Quickshell

// Tailscale: on/off, own address and the machines on the network (click copies the IP address).
// On/off requires running this once: sudo tailscale set --operator=$USER
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 8

    property bool running: LastState.tailscale
    onRunningChanged: LastState.tailscale = running
    property string tailnet: ""
    property string selfIp: ""
    property var peers: []           // [{ host, ip, online, os }]
    property string message: ""
    property string copied: ""
    property bool showOffline: false
    signal close()

    function refresh() { statusProc.running = true }
    function toggle() {
        m.message = ""
        toggleProc.script = m.running ? "tailscale down" : "tailscale up"
        toggleProc.running = true
    }
    function copy(ip) {
        Quickshell.execDetached(["wl-copy", ip])
        m.copied = ip
        copiedTimer.restart()
    }
    Component.onCompleted: refresh()
    Timer { interval: 3000; repeat: true; running: true; onTriggered: m.refresh() }
    Timer { id: copiedTimer; interval: 1500; onTriggered: m.copied = "" }

    Sh {
        id: statusProc
        command: ["tailscale", "status", "--json"]
        onResult: text => {
            let j
            try { j = JSON.parse(text) } catch (e) { m.running = false; m.peers = []; return }
            m.running = j.BackendState === "Running"
            m.tailnet = (j.CurrentTailnet || {}).Name || ""
            m.selfIp = ((j.Self || {}).TailscaleIPs || [""])[0]
            const arr = []
            for (const k in (j.Peer || {})) {
                const p = j.Peer[k]
                arr.push({ host: p.HostName, ip: (p.TailscaleIPs || [""])[0], online: !!p.Online, os: p.OS })
            }
            arr.sort((a, b) => (b.online - a.online) || a.host.localeCompare(b.host))
            m.peers = arr
        }
    }
    Sh {
        id: toggleProc
        onResult: text => {
            if (toggleProc.exitCode !== 0)
                m.message = /denied|operator/i.test(text) ? "Permission denied. Run once: sudo tailscale set --operator=$USER"
                                                          : text.trim().split("\n").pop()
            m.refresh()
        }
    }

    MenuHeader {
        width: parent.width
        title: "Tailscale"
        showToggle: true
        checked: m.running
        onToggled: m.toggle()
    }

    MenuRow {
        visible: m.running && m.selfIp !== ""
        width: parent.width
        height: visible ? 34 : 0
        icon: "shield-check"
        active: true
        label: m.tailnet
        detail: m.copied === m.selfIp ? "copied" : m.selfIp
        onClicked: m.copy(m.selfIp)
    }
    Text {
        visible: !m.running
        text: "Tailscale is off"
        color: Theme.dim
        font { family: Theme.font; pixelSize: 12 }
    }

    Column {
        visible: m.running
        width: parent.width
        spacing: 2
        Repeater {
            model: m.running ? m.peers.filter(p => p.online || m.showOffline) : []
            delegate: MenuRow {
                required property var modelData
                width: parent.width
                icon: /mac|ios/i.test(modelData.os) ? "laptop" : /android/i.test(modelData.os) ? "smartphone" : "server"
                label: modelData.host
                active: false
                detail: m.copied === modelData.ip ? "copied" : (modelData.online ? modelData.ip : "offline")
                opacity: modelData.online ? 1 : 0.5
                onClicked: m.copy(modelData.ip)
            }
        }
    }

    MenuRow {
        readonly property int offlineCount: m.peers.filter(p => !p.online).length
        visible: m.running && offlineCount > 0
        width: parent.width
        height: visible ? 34 : 0
        icon: m.showOffline ? "chevron-up" : "chevron-right"
        label: m.showOffline ? "Hide offline machines" : "Offline machines: " + offlineCount
        onClicked: m.showOffline = !m.showOffline
    }

    Text {
        visible: m.message !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: m.message
        color: Theme.danger
        font { family: Theme.font; pixelSize: 12 }
    }
}
