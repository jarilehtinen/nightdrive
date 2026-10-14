import QtQuick
import Quickshell

// Bluetooth: on/off, devices, connecting, scanning for devices. Uses bluetoothctl.
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 8

    property bool powered: LastState.bluetooth
    onPoweredChanged: LastState.bluetooth = powered
    property var devices: []         // [{ mac, connected, paired, battery, name, named }]
    // Nameless devices (only an address: mostly nearby phones, Macs and AirTags with a changing random address) are
    // hidden unless paired; "Show hidden devices" lists them too
    property bool showHidden: false
    readonly property var hidden: devices.filter(d => !d.named && !d.paired && !d.connected)
    readonly property var shown: showHidden ? devices : devices.filter(d => hidden.indexOf(d) < 0)
    property bool scanning: false
    property string busy: ""
    property string message: ""
    property string messageMac: ""   // the device the error is about: it clears once that device is connected
    signal close()

    function refresh() { powerProc.running = true; listProc.running = true }
    function scan() {
        if (m.scanning || !m.powered) return
        m.scanning = true
        scanProc.running = true
    }
    function activate(d) {
        if (m.busy !== "") return
        m.busy = d.mac; m.message = ""; m.messageMac = d.mac
        actProc.environment = { "MAC": d.mac, "MODE": d.connected ? "disconnect" : (d.paired ? "connect" : "pair") }
        actProc.running = true
    }
    function iconFor(name) {
        return /head|buds|airpods|wh-|wf-|sony/i.test(name) ? "headphones"
             : /mouse|mx |trackpad/i.test(name) ? "mouse"
             : /keyboard|keys/i.test(name) ? "keyboard"
             : /phone|iphone|pixel|galaxy/i.test(name) ? "smartphone"
             : /watch/i.test(name) ? "watch"
             : /speaker|boom|jbl|soundbar/i.test(name) ? "speaker" : "bluetooth"
    }
    Component.onCompleted: refresh()

    Timer { interval: 2500; repeat: true; running: true; onTriggered: m.refresh() }

    Sh {
        id: powerProc
        command: ["bluetoothctl", "show"]
        onResult: text => m.powered = /Powered:\s*yes/.test(text)
    }
    Sh {
        id: listProc
        script: 'bluetoothctl devices | while read -r _ mac name; do\n' +
                '  info=$(bluetoothctl info "$mac")\n' +
                '  c=$(grep -c "Connected: yes" <<<"$info"); p=$(grep -c "Paired: yes" <<<"$info"); n=$(grep -c "^\\s*Name:" <<<"$info")\n' +
                '  b=$(grep -oP "Battery Percentage: 0x\\w+ \\(\\K[0-9]+" <<<"$info")\n' +
                '  echo "$mac|$c|$p|$b|$n|$name"\n' +
                'done'
        onResult: text => {
            const arr = []
            for (const line of text.split("\n")) {
                const f = line.split("|")
                if (f.length < 6) continue
                arr.push({ mac: f[0], connected: f[1] !== "0", paired: f[2] !== "0", battery: f[3], named: f[4] !== "0",
                           name: f.slice(5).join("|") })
            }
            arr.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
            m.devices = arr
            // e.g. connecting failed while the headphones were off, and they connected by themselves once switched on
            if (m.message !== "" && arr.some(d => d.mac === m.messageMac && d.connected)) m.message = ""
        }
    }
    Sh {
        id: scanProc
        // 20 s: headphones' names (e.g. AirPods) can take a while to arrive; the list fills in as they do (refresh timer)
        command: ["bluetoothctl", "--timeout", "20", "scan", "on"]
        onResult: text => { m.scanning = false; m.refresh() }
    }
    Sh {
        id: actProc
        script: 'case "$MODE" in\n' +
                '  disconnect) bluetoothctl disconnect "$MAC" ;;\n' +
                '  connect) bluetoothctl connect "$MAC" ;;\n' +
                '  pair) bluetoothctl pair "$MAC" && bluetoothctl trust "$MAC" && bluetoothctl connect "$MAC" ;;\n' +
                'esac'
        onResult: text => {
            m.busy = ""
            if (actProc.exitCode !== 0) {
                const lines = text.trim().split("\n")
                m.message = lines[lines.length - 1]
            }
            m.refresh()
        }
    }

    MenuHeader {
        width: parent.width
        title: "Bluetooth"
        showToggle: true
        checked: m.powered
        onToggled: {
            m.powered = !m.powered
            Quickshell.execDetached(["bluetoothctl", "power", m.powered ? "on" : "off"])
        }
    }

    Text {
        visible: !m.powered
        text: "Bluetooth is off"
        color: Theme.dim
        font { family: Theme.font; pixelSize: 12 }
    }
    Text {
        visible: m.powered && m.shown.length === 0
        text: "No devices. Press Scan for devices."
        color: Theme.dim
        font { family: Theme.font; pixelSize: 12 }
    }

    Column {
        visible: m.powered
        width: parent.width
        spacing: 2
        Repeater {
            model: m.powered ? m.shown : []
            delegate: MenuRow {
                required property var modelData
                width: parent.width
                icon: m.iconFor(modelData.name)
                label: modelData.name
                active: modelData.connected
                checkIcon: modelData.connected ? "check" : ""
                hoverCheckIcon: modelData.connected ? "unplug" : ""   // a click disconnects
                busy: m.busy === modelData.mac
                detail: modelData.battery !== "" ? modelData.battery + "%"
                      : (!modelData.paired ? "not paired" : "")
                onClicked: m.activate(modelData)
            }
        }
    }

    MenuRow {
        visible: m.powered && m.hidden.length > 0
        width: parent.width
        height: visible ? 34 : 0
        icon: m.showHidden ? "eye-off" : "eye"
        action: true
        label: (m.showHidden ? "Hide unnamed devices" : "Show hidden devices") + " (" + m.hidden.length + ")"
        onClicked: m.showHidden = !m.showHidden
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
        visible: m.powered
        width: parent.width
        height: visible ? 34 : 0
        icon: "bluetooth-searching"
        action: true
        label: m.scanning ? "Scanning…" : "Scan for devices"
        onClicked: m.scan()
    }
    MenuRow {
        width: parent.width
        icon: "settings"
        action: true
        label: "Bluetooth settings…"
        onClicked: { Quickshell.execDetached(["blueman-manager"]); m.close() }
    }
}
