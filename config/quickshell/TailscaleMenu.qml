import QtQuick
import Quickshell

// Tailscale: on/off, this machine and the other machines on the network, online and offline (click copies the IP address).
// On/off requires running this once: sudo tailscale set --operator=$USER
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 8

    property bool running: LastState.tailscale
    onRunningChanged: LastState.tailscale = running
    property string selfIp: ""
    property string selfName: ""
    property var peers: []           // [{ host, ip, online, os }]
    property string message: ""
    property string copied: ""
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
            m.selfIp = ((j.Self || {}).TailscaleIPs || [""])[0]
            m.selfName = (j.Self || {}).HostName || ""
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
        icon: "laptop-minimal-check"   // this machine, connected
        tinted: true
        label: m.selfName        // this machine
        detail: m.copied === m.selfIp ? "copied" : m.selfIp
        onClicked: m.copy(m.selfIp)
    }
    Text {
        visible: !m.running
        text: "Tailscale is off"
        color: Theme.dim
        font { family: Theme.font; pixelSize: 12 }
    }

    // The other machines: online ones first, then offline ones (dimmed) under their own title
    Repeater {
        model: m.running ? [{ title: "Online", online: true }, { title: "Offline", online: false }] : []
        delegate: Column {
            id: sec
            required property var modelData
            readonly property var list: m.peers.filter(p => p.online === modelData.online)
            visible: list.length > 0
            width: m.width
            spacing: 2
            MenuSection { title: sec.modelData.title; bottomPadding: 4 }
            Repeater {
                model: sec.list
                delegate: MenuRow {
                    required property var modelData
                    width: sec.width
                    icon: /mac|ios/i.test(modelData.os) ? "laptop" : /android/i.test(modelData.os) ? "smartphone" : "server"
                    label: modelData.host
                    active: false
                    detail: m.copied === modelData.ip ? "copied" : modelData.ip
                    opacity: modelData.online ? 1 : 0.5
                    onClicked: m.copy(modelData.ip)
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

    Divider { padBottom: 6 }
    MenuRow {
        width: parent.width
        icon: "external-link"
        action: true
        label: "Admin console"
        onClicked: { Quickshell.execDetached(["xdg-open", "https://login.tailscale.com/admin/machines"]); m.close() }
    }
}
