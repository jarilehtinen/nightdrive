import QtQuick
import Quickshell

// Battery and display: charging state and time remaining (upower), the battery's details (topbar/scripts/sysinfo battery:
// power draw, temperature, health = capacity left of the original, cycles, voltage, age) and brightness levels (brightnessctl).
Column {
    id: m
    width: parent ? parent.width : 300
    spacing: 10

    property int percent: 0
    property string state: ""
    property string timeText: ""
    property var bat: null           // sysinfo battery
    property real screen: -1         // -1 = no display backlight (a VM)
    property real keys: -1           // -1 = no keyboard backlight
    property real pendingScreen: -1
    property real pendingKeys: -1
    signal close()


    function fmt(v, unit) {
        let min = Math.round(parseFloat(v) * (/hour/.test(unit) ? 60 : /second/.test(unit) ? 1 / 60 : 1))
        const h = Math.floor(min / 60)
        return h > 0 ? h + " h " + (min % 60) + " min" : min + " min"
    }
    function refresh() { battProc.running = true; detailProc.running = true; briProc.running = true; kbdProc.running = true }
    Component.onCompleted: refresh()
    Timer { interval: 3000; repeat: true; running: true; onTriggered: m.refresh() }

    Timer {
        id: apply; interval: 60
        onTriggered: {
            if (m.pendingScreen >= 0) { Quickshell.execDetached(["brightnessctl", "-c", "backlight", "-n2", "set", Math.round(m.pendingScreen * 100) + "%"]); m.pendingScreen = -1 }
            if (m.pendingKeys >= 0) { Quickshell.execDetached(["brightnessctl", "-d", "kbd_backlight", "set", Math.round(m.pendingKeys * 100) + "%"]); m.pendingKeys = -1 }
        }
    }

    Sh {
        id: battProc
        // The machine's own battery, found like in topbar/scripts/status (MacBook: macsmc-battery; Bluetooth devices skipped)
        script: 'for d in /sys/class/power_supply/*; do [ "$(cat "$d/type")" = Battery ] && [ "$(cat "$d/scope" 2>/dev/null)" != Device ] &&
                 { upower -i "/org/freedesktop/UPower/devices/battery_$(basename "$d" | tr - _)"; break; }; done'
        onResult: text => {
            const g = re => { const r = text.match(re); return r ? r[1].trim() : "" }
            m.percent = parseInt(g(/percentage:\s*(\d+)/)) || 0
            m.state = g(/state:\s*(\S+)/)
            const tte = text.match(/time to empty:\s*([\d.,]+)\s*(\w+)/)
            const ttf = text.match(/time to full:\s*([\d.,]+)\s*(\w+)/)
            m.timeText = m.state === "discharging" && tte ? m.fmt(tte[1].replace(",", "."), tte[2])
                       : m.state === "charging" && ttf ? m.fmt(ttf[1].replace(",", "."), ttf[2]) : ""
        }
    }
    Sh {
        id: detailProc
        command: ["bash", "-c", "~/.config/topbar/scripts/sysinfo battery"]
        onResult: text => { try { m.bat = JSON.parse(text) } catch (e) { m.bat = null } }
    }
    Sh {
        id: briProc
        // -c backlight: without a backlight brightnessctl would pick the first LED (a keyboard's Compose light)
        command: ["brightnessctl", "-m", "-c", "backlight"]
        onResult: text => {
            if (screenSlider.pressed || m.pendingScreen >= 0) return
            const f = text.trim().split(",")
            m.screen = f.length >= 4 ? parseInt(f[3]) / 100 : -1
        }
    }
    Sh {
        id: kbdProc
        command: ["brightnessctl", "-m", "-d", "kbd_backlight"]
        onResult: text => {
            if (keySlider.pressed || m.pendingKeys >= 0) return
            const f = text.trim().split(",")
            m.keys = f.length >= 4 ? parseInt(f[3]) / 100 : -1
        }
    }

    MenuHeader { width: parent.width; title: "Battery & display" }

    // ASCII battery: [█████████░░░░░░░░░░░] 47 % (the bar's colour shows charging / low; no icon, it would say the same)
    readonly property int cells: 26   // fills the menu width next to the percentage
    readonly property color battColor: m.state === "charging" ? Theme.accent : (m.percent <= 10 ? Theme.danger : (m.percent <= 20 ? Theme.warning : Theme.primary))
    readonly property string battBar: {
        const n = Math.max(0, Math.min(cells, Math.round(m.percent / 100 * cells)))
        return "[" + "█".repeat(n) + "░".repeat(cells - n) + "]"
    }

    Column {
        width: parent.width
        spacing: 7   // the bar and the status line below it
        Row {
            spacing: 12
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: m.battBar
                color: m.battColor
                font { family: Theme.font; pixelSize: 14 }
            }
            Text {
                id: pct
                anchors.verticalCenter: parent.verticalCenter
                text: m.percent + " %"
                color: Theme.text
                font { family: Theme.font; pixelSize: 15; bold: true }
            }
        }
        Text {
            text: (m.state === "discharging" ? "Discharging" : m.state === "charging" ? "Charging"
                 : m.state === "fully-charged" ? "Fully charged" : m.state === "pending-charge" ? "Not charging" : m.state)
                + (m.timeText !== "" ? " · " + m.timeText + (m.state === "charging" ? " until full" : " remaining") : "")
            color: Theme.dim
            font { family: Theme.font; pixelSize: 12 }
        }
    }

    Divider { visible: m.bat !== null }
    Text {
        visible: m.bat !== null
        text: "DETAILS"
        color: Theme.primary
        font { family: Theme.font; pixelSize: 11; letterSpacing: 0.6 }
    }
    Column {
        visible: m.bat !== null
        width: parent.width
        spacing: 2
        Repeater {
            model: !m.bat ? [] : [
                { icon: "zap", label: "Power", detail: m.bat.watts > 0 ? m.bat.watts + " W" : "" },
                { icon: "thermometer", label: "Temperature", detail: m.bat.temp !== null ? m.bat.temp + " °C" : "", danger: m.bat.temp >= 45 },
                { icon: "heart-pulse", label: "Health",
                  detail: m.bat.health !== null ? m.bat.health + " % · " + m.bat.fullWh + " / " + m.bat.designWh + " Wh" : "" },
                { icon: "repeat", label: "Cycles", detail: m.bat.cycles !== null ? String(m.bat.cycles) : "" },
                { icon: "activity", label: "Voltage", detail: m.bat.volts !== null ? m.bat.volts.toFixed(2) + " V" : "" },
                { icon: "calendar", label: "Manufactured", detail: m.bat.made }
            ].filter(r => r.detail !== "")
            delegate: MenuRow {
                required property var modelData
                width: parent.width
                height: 28
                interactive: false
                icon: modelData.icon
                label: modelData.label
                detail: modelData.detail
                danger: !!modelData.danger
            }
        }
    }

    Divider { visible: m.screen >= 0 || m.keys >= 0 }

    Row {
        visible: m.screen >= 0
        width: parent.width
        spacing: 12
        Text {
            id: sunIcon
            width: 22
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: Icons.g("sun")
            color: Theme.text
            font { family: Icons.family; pixelSize: 18 }
        }
        Slider {
            id: screenSlider
            width: parent.width - sunIcon.width - pctS.width - 24
            anchors.verticalCenter: parent.verticalCenter
            value: m.screen
            onMoved: v => { m.screen = v; m.pendingScreen = v; if (!apply.running) apply.start() }
        }
        Text {
            id: pctS
            width: 44
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Math.round(m.screen * 100) + "%"
            color: Theme.text
            font { family: Theme.font; pixelSize: 13 }
        }
    }

    Row {
        visible: m.keys >= 0
        width: parent.width
        spacing: 12
        Text {
            id: kbIcon
            width: 22
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: Icons.g("keyboard")
            color: Theme.text
            font { family: Icons.family; pixelSize: 18 }
        }
        Slider {
            id: keySlider
            width: parent.width - kbIcon.width - pctK.width - 24
            anchors.verticalCenter: parent.verticalCenter
            value: Math.max(0, m.keys)
            onMoved: v => { m.keys = v; m.pendingKeys = v; if (!apply.running) apply.start() }
        }
        Text {
            id: pctK
            width: 44
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Math.round(Math.max(0, m.keys) * 100) + "%"
            color: Theme.text
            font { family: Theme.font; pixelSize: 13 }
        }
    }
}
