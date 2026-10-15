import QtQuick
import Quickshell

// The launcher's Settings › Wi-Fi, Bluetooth, Sound and Tailscale, and Status (the top bar's System and Claude usage): the
// same things as the top bar's menus (WifiMenu, BluetoothMenu, VolumeMenu, TailscaleMenu, SystemMenu, ClaudeMenu) as
// launcher rows, so the launcher doesn't hand over to a menu.
// Launcher.qml asks it like its private extension (levels, titles, parents, items, activate, footer, entered).
// The data is read while one of these levels is open; rows use the launcher's kinds (header, hint, stat, action) and a few
// own ones, handled in activate().
Item {
    id: s
    property var launcher: null

    readonly property var levels: ["wifi", "wifipw", "bluetooth", "sound", "tailscale", "status"]
    readonly property var titles: ({ status: "System › Status", wifi: "Settings › Wi-Fi", wifipw: "Wi-Fi › Password", bluetooth: "Settings › Bluetooth",
                                     sound: "Settings › Sound", tailscale: "Settings › Tailscale" })
    readonly property var parents: ({ status: "system", wifi: "settings", wifipw: "wifi", bluetooth: "settings", sound: "settings", tailscale: "settings" })
    readonly property string level: launcher ? launcher.level : ""
    readonly property bool shown: launcher !== null && launcher.open && levels.indexOf(level) >= 0

    function hint(t) { return [{ kind: "hint", name: t }] }
    function row(r) { return { item: r, text: r.kind === "header" || r.kind === "hint" ? "" : r.name, extra: r.extra || "" } }
    function sel() { if (launcher) launcher.keepSelection() }   // a refresh rebuilds the rows: keep the selected one

    function footer(level, query) {
        const cur = launcher.results[launcher.selIndex] || {}
        if (cur.kind === "slider") return "Left+Right: " + cur.name.toLowerCase() + "  ·  Enter: mute on/off"
        if (cur.kind === "systoggle") return "Enter: on/off"
        if (cur.kind === "wifinet") return cur.active ? "" : "Enter: connect"
        if (cur.kind === "btdev") return "Enter: " + (cur.connected ? "disconnect" : cur.paired ? "connect" : "pair and connect")
        if (cur.kind === "sounddev") return "Enter: use this"
        if (cur.kind === "tsmachine") return "Enter: copy IP address  ·  Cmd+C: copy"
        if (cur.copy !== undefined) return "Cmd+C: copy"
        if (level === "wifipw") return query !== "" ? "Enter: connect  ·  Esc: back" : ""
        return ""
    }
    function opened() {}
    function entered(level) {
        if (level === "wifi") { wifiMessage = ""; wifiRefresh(); rescan(); if (activeSsid !== "") ipProc.running = true }
        if (level === "bluetooth") { btMessage = ""; btRefresh() }
        if (level === "sound") soundRefresh()
        if (level === "tailscale") { tsMessage = ""; tsProc.running = true }
        if (level === "status") { sysProc.running = true; claudeProc.running = true }
    }
    function shiftActivate(item) {}

    function items(level, q) {
        if (level === "wifi") return { all: wifiRows().map(row) }
        if (level === "wifipw") return [{ kind: "wificonnect", name: "Connect to “" + askFor + "”", glyph: "lock",
                                          summary: launcher.query === "" ? "type the password" : undefined, dimmed: launcher.query === "" }]
        if (level === "bluetooth") return { all: btRows().map(row) }
        if (level === "sound") return { all: soundRows().map(row) }
        if (level === "tailscale") return { all: tsRows().map(row) }
        if (level === "status") return { all: statusRows().map(row) }
        return []
    }

    // Enter on a row. Returns true when the row was one of ours.
    function activate(it) {
        if (it.kind === "systoggle") {
            sel()
            if (it.key === "wifi") {
                wifiOn = !wifiOn
                TopBar.run("nmcli radio wifi " + (wifiOn ? "on" : "off"), "wifi")
                if (!wifiOn) nets = []
            } else if (it.key === "bluetooth") {
                powered = !powered
                Quickshell.execDetached(["bluetoothctl", "power", powered ? "on" : "off"])
            } else if (it.key === "tailscale") {
                tsMessage = ""
                tsToggle.script = tsRunning ? "tailscale down" : "tailscale up"
                tsToggle.running = true
            }
            return true
        }
        if (it.kind === "wifinet") { sel(); wifiActivate(it.net); return true }
        if (it.kind === "wifidisconnect") { sel(); wifiActivate(activeNet); return true }
        if (it.kind === "wififorget") {
            if (!arm(it.armKey)) return true
            connecting = activeSsid
            forgetProc.environment = { "SSID": activeSsid }
            forgetProc.running = true
            return true
        }
        if (it.kind === "wificonnect") {
            if (launcher.query === "") { launcher.shakeNow(); return true }
            connectTo(askFor, launcher.query)
            launcher.go("wifi")
            return true
        }
        if (it.kind === "btdev") { sel(); btActivate(it.dev); return true }
        if (it.kind === "bthidden") { sel(); showHidden = !showHidden; return true }
        if (it.kind === "btscan") { sel(); btScan(); return true }
        if (it.kind === "slider") { sel(); toggleMute(it.key); return true }
        if (it.kind === "sounddev") {
            sel()
            Quickshell.execDetached(["wpctl", "set-default", String(it.id)])
            soundSoon.restart()
            return true
        }
        if (it.kind === "tsmachine") { copyText(it.ip); return true }
        return false
    }
    // Rows that need a second Enter (the launcher shows the armHint while armed); true = confirmed
    function arm(key) {
        if (launcher.armed !== key) { launcher.armed = key; disarmTimer.restart(); return false }
        launcher.armed = ""
        return true
    }
    Timer { id: disarmTimer; interval: 4000; onTriggered: if (s.launcher) s.launcher.armed = "" }

    // ⌘C (Hyprland sends Ctrl+Insert) or Enter on a row with a `copy` value: the row says "copied" for a moment
    function copyText(v) {
        sel()
        Quickshell.execDetached(["wl-copy", v])
        copied = v
        copiedTimer.restart()
    }
    // Values that change every second are bound in the row (the launcher asks with the row's `live` key), not baked into
    // the rows: rebuilding the rows every second made the list jump while moving in it
    function liveText(key) {
        if (key === "wifirate") return "↓ " + fmtRate(rxRate) + "   ↑ " + fmtRate(txRate)
        return statusLive(key)
    }

    // ---- Sliders (Sound): ←/→ and the row's slider call these ----
    function sliderValue(key) { return key === "mic" ? micVolume : volume }
    function setSlider(key, v) {
        sel()
        if (key === "mic") { micVolume = v; micPending = v } else { volume = v; pending = v }
        if (!volApply.running) volApply.start()
    }
    function stepSlider(key, dir) {
        const p = Math.round(sliderValue(key) * 100)
        const n = dir > 0 ? (Math.floor(p / 5) + 1) * 5 : (p % 5 === 0 ? p - 5 : Math.floor(p / 5) * 5)
        setSlider(key, Math.max(0, Math.min(100, n)) / 100)
    }

    // ================= Wi-Fi (nmcli; as in WifiMenu) =================
    property bool wifiOn: LastState.wifi
    onWifiOnChanged: LastState.wifi = wifiOn
    property var nets: []            // [{ ssid, signal, secure, active, known }]
    property var knownSet: ({})
    property string connecting: ""
    property string askFor: ""       // the network whose password is being typed (level wifipw)
    property string wifiMessage: ""
    property string publicIp: ""
    property real rxRate: 0
    property real txRate: 0
    property real lastRx: -1
    property real lastTx: -1
    property real lastT: 0
    readonly property var activeNet: nets.find(n => n.active) || null
    readonly property string activeSsid: activeNet ? activeNet.ssid : ""
    onActiveSsidChanged: { publicIp = ""; if (activeSsid !== "" && level === "wifi") ipProc.running = true }

    function splitTerse(line) {    // nmcli -t: fields separated by ':', a ':' inside a field escaped as \:
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
    function sigIcon(v) { return v >= 75 ? "wifi" : v >= 50 ? "wifi-high" : v >= 25 ? "wifi-low" : "wifi-zero" }
    function fmtRate(b) {
        const bits = b * 8
        return bits >= 1e9 ? (bits / 1e9).toFixed(2) + " Gb/s" : bits >= 1e6 ? (bits / 1e6).toFixed(1) + " Mb/s"
             : bits >= 1e3 ? Math.round(bits / 1e3) + " kb/s" : Math.round(bits) + " b/s"
    }
    function wifiRefresh() { radioProc.running = true; knownProc.running = true; listProc.running = true }
    function rescan() { Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]) }
    function connectTo(ssid, password) {
        wifiMessage = ""
        connecting = ssid
        connectProc.environment = { "SSID": ssid, "PW": password || "" }
        connectProc.running = true
    }
    function wifiActivate(n) {
        if (!n || connecting !== "") return
        if (n.active) {
            connecting = n.ssid
            disconnectProc.environment = { "SSID": n.ssid }
            disconnectProc.running = true
        } else if (n.secure && !n.known) {
            askFor = n.ssid
            launcher.go("wifipw")
        } else connectTo(n.ssid, "")
    }
    function wifiRows() {
        const r = [{ kind: "systoggle", key: "wifi", name: "Wi-Fi", glyph: wifiOn ? "wifi" : "wifi-off", summary: wifiOn ? "on" : "off" }]
        if (!wifiOn) return r
        const a = activeNet
        if (a) {
            r.push({ kind: "header", name: "Connected" },
                   { kind: "stat", name: a.ssid, glyph: sigIcon(a.signal), live: "wifirate" },
                   { kind: "stat", name: "Public IP", glyph: "globe", copy: /^[0-9a-fA-F:.]+$/.test(publicIp) ? publicIp : undefined,
                     summary: copied !== "" && copied === publicIp ? "copied" : publicIp || "…" },
                   { kind: "wifidisconnect", name: "Disconnect", glyph: "unplug", summary: connecting === a.ssid ? "…" : undefined },
                   { kind: "wififorget", name: "Forget network", glyph: "trash-2", armKey: "forget:" + a.ssid,
                     armHint: "press Enter again to forget it and its password" })
        }
        const others = nets.filter(n => !n.active)
        r.push({ kind: "header", name: a ? "Other networks" : "Networks" })
        if (others.length === 0) r.push({ kind: "hint", name: "Searching for networks…" })
        for (const n of others)
            r.push({ kind: "wifinet", name: n.ssid, glyph: sigIcon(n.signal), net: n, active: false,
                     summary: connecting === n.ssid ? "connecting…" : n.known ? "saved" : undefined,
                     trailGlyph: connecting !== n.ssid && !n.known && n.secure ? "lock" : undefined })
        if (wifiMessage !== "") r.push({ kind: "hint", name: wifiMessage })
        r.push({ kind: "header", name: "More" })
        r.push({ kind: "action", name: "Network settings…", glyph: "settings", cmd: ["nm-connection-editor"], extra: "advanced ip dns vpn" })
        return r
    }
    Timer { interval: 3000; repeat: true; running: s.shown && s.level === "wifi"; onTriggered: s.wifiRefresh() }
    Timer { interval: 10000; repeat: true; running: s.shown && s.level === "wifi"; onTriggered: s.rescan() }
    Timer { interval: 60000; repeat: true; running: s.shown && s.level === "wifi" && s.activeSsid !== ""; onTriggered: ipProc.running = true }
    Timer { interval: 1000; repeat: true; running: s.shown && s.level === "wifi" && s.activeSsid !== ""; triggeredOnStart: true; onTriggered: rateProc.running = true }
    Sh {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        onResult: text => { if ((text.trim() === "enabled") !== s.wifiOn) { s.sel(); s.wifiOn = text.trim() === "enabled" } }
    }
    Sh {
        id: knownProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        onResult: text => {
            const set = {}
            for (const line of text.split("\n")) {
                const f = s.splitTerse(line)
                if (f.length >= 2 && f[1] === "802-11-wireless") set[f[0]] = true
            }
            if (JSON.stringify(set) !== JSON.stringify(s.knownSet)) s.knownSet = set
        }
    }
    Sh {
        id: listProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        onResult: text => {
            const by = {}
            for (const line of text.split("\n")) {
                if (!line) continue
                const f = s.splitTerse(line)
                if (f.length < 4 || f[1] === "") continue
                const n = { ssid: f[1], signal: parseInt(f[2]) || 0, secure: f[3] !== "" && f[3] !== "--", active: f[0] === "*", known: !!s.knownSet[f[1]] }
                const old = by[n.ssid]
                if (!old || n.active || (!old.active && n.signal > old.signal)) by[n.ssid] = n
            }
            const arr = Object.values(by)
            arr.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
            if (JSON.stringify(arr) === JSON.stringify(s.nets)) return
            s.sel()
            s.nets = arr
        }
    }
    Sh {
        id: rateProc
        script: 'for d in /sys/class/net/*/wireless; do i=${d%/wireless}; echo "$(cat $i/statistics/rx_bytes) $(cat $i/statistics/tx_bytes)"; break; done'
        onResult: text => {
            const f = text.trim().split(/\s+/).map(Number)
            if (f.length < 2 || isNaN(f[0])) return
            const now = Date.now()
            if (s.lastRx >= 0 && now > s.lastT) {
                const dt = (now - s.lastT) / 1000
                s.rxRate = Math.max(0, (f[0] - s.lastRx) / dt)
                s.txRate = Math.max(0, (f[1] - s.lastTx) / dt)
            }
            s.lastRx = f[0]; s.lastTx = f[1]; s.lastT = now
        }
    }
    Sh {
        id: ipProc   // external service: api.ipify.org (as in WifiMenu)
        script: 'curl -s --max-time 5 https://api.ipify.org'
        onResult: text => {
            const ip = text.replace(/\s+/g, "")
            const v = ipProc.exitCode === 0 && /^[0-9a-fA-F:.]{3,45}$/.test(ip) ? ip : "unavailable"
            if (v === s.publicIp) return
            s.sel()
            s.publicIp = ipProc.exitCode === 0 && /^[0-9a-fA-F:.]{3,45}$/.test(ip) ? ip : "unavailable"
        }
    }
    Sh {
        id: connectProc
        script: 'if [ -n "$PW" ]; then nmcli --wait 20 device wifi connect "$SSID" password "$PW"; else nmcli --wait 20 device wifi connect "$SSID"; fi'
        onResult: text => {
            s.sel()
            s.connecting = ""
            if (connectProc.exitCode !== 0) {
                const lines = text.trim().split("\n")
                s.wifiMessage = lines[lines.length - 1].replace(/^Error:\s*/, "")
            } else { s.wifiMessage = ""; s.askFor = "" }
            s.wifiRefresh()
        }
    }
    Sh {
        id: disconnectProc
        script: 'nmcli connection down id "$SSID"'
        onResult: text => { s.connecting = ""; s.wifiRefresh() }
    }
    Sh {
        id: forgetProc   // by the SSID stored in each profile: a profile's name can differ from it ("Home 1")
        script: 'nmcli -t -f UUID,TYPE connection show | while IFS=: read -r uuid type; do
  [ "$type" = 802-11-wireless ] && [ "$(nmcli -g 802-11-wireless.ssid connection show "$uuid")" = "$SSID" ] && nmcli connection delete uuid "$uuid"
done; true'
        onResult: text => { s.connecting = ""; s.wifiRefresh(); TopBar.refresh("wifi") }
    }

    // ================= Bluetooth (bluetoothctl; as in BluetoothMenu) =================
    property bool powered: LastState.bluetooth
    onPoweredChanged: LastState.bluetooth = powered
    property var devices: []         // [{ mac, connected, paired, battery, name, named }]
    property bool showHidden: false
    property bool scanning: false
    property string btBusy: ""
    property string btMessage: ""
    function btRefresh() { powerProc.running = true; btListProc.running = true }
    function btScan() { if (!scanning && powered) { scanning = true; scanProc.running = true } }
    function btActivate(d) {
        if (btBusy !== "") return
        btBusy = d.mac; btMessage = ""
        actProc.environment = { "MAC": d.mac, "MODE": d.connected ? "disconnect" : (d.paired ? "connect" : "pair") }
        actProc.running = true
    }
    function btIcon(name) {
        return /head|buds|airpods|wh-|wf-|sony/i.test(name) ? "headphones" : /mouse|mx |trackpad/i.test(name) ? "mouse"
             : /keyboard|keys/i.test(name) ? "keyboard" : /phone|iphone|pixel|galaxy/i.test(name) ? "smartphone"
             : /watch/i.test(name) ? "watch" : /speaker|boom|jbl|soundbar/i.test(name) ? "speaker" : "bluetooth"
    }
    function btRows() {
        const r = [{ kind: "systoggle", key: "bluetooth", name: "Bluetooth", glyph: powered ? "bluetooth" : "bluetooth-off", summary: powered ? "on" : "off" }]
        if (!powered) return r
        // Nameless devices (only an address: nearby phones, Macs and AirTags) are hidden unless paired, as in the menu
        const hidden = devices.filter(d => !d.named && !d.paired && !d.connected)
        const list = showHidden ? devices : devices.filter(d => hidden.indexOf(d) < 0)
        r.push({ kind: "header", name: "Devices" })
        if (list.length === 0) r.push({ kind: "hint", name: "No devices: Scan for devices below" })
        for (const d of list)
            r.push({ kind: "btdev", name: d.name, glyph: btIcon(d.name), dev: d, connected: d.connected, paired: d.paired,
                     summary: btBusy === d.mac ? "…" : d.battery !== "" ? d.battery + "%" : !d.paired ? "not paired" : undefined,
                     trailGlyph: d.connected && btBusy !== d.mac ? "check" : undefined })
        if (btMessage !== "") r.push({ kind: "hint", name: btMessage })
        r.push({ kind: "header", name: "More" })
        if (hidden.length > 0)
            r.push({ kind: "bthidden", name: (showHidden ? "Hide unnamed devices" : "Show hidden devices") + " (" + hidden.length + ")",
                     glyph: showHidden ? "eye-off" : "eye" })
        r.push({ kind: "btscan", name: "Scan for devices", glyph: "bluetooth-searching", summary: scanning ? "scanning…" : undefined, extra: "pair new add" },
               { kind: "action", name: "Bluetooth settings…", glyph: "settings", cmd: ["blueman-manager"] })
        return r
    }
    Timer { interval: 2500; repeat: true; running: s.shown && s.level === "bluetooth"; onTriggered: s.btRefresh() }
    Sh {
        id: powerProc
        command: ["bluetoothctl", "show"]
        onResult: text => { const p = /Powered:\s*yes/.test(text); if (p !== s.powered) { s.sel(); s.powered = p } }
    }
    Sh {
        id: btListProc
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
                arr.push({ mac: f[0], connected: f[1] !== "0", paired: f[2] !== "0", battery: f[3], named: f[4] !== "0", name: f.slice(5).join("|") })
            }
            arr.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
            if (JSON.stringify(arr) === JSON.stringify(s.devices)) return
            s.sel()
            s.devices = arr
        }
    }
    Sh {
        id: scanProc   // 20 s: headphones' names can take a while to arrive; the list fills in as they do
        command: ["bluetoothctl", "--timeout", "20", "scan", "on"]
        onResult: text => { s.sel(); s.scanning = false; s.btRefresh() }
    }
    Sh {
        id: actProc
        script: 'case "$MODE" in\n' +
                '  disconnect) bluetoothctl disconnect "$MAC" ;;\n' +
                '  connect) bluetoothctl connect "$MAC" ;;\n' +
                '  pair) bluetoothctl pair "$MAC" && bluetoothctl trust "$MAC" && bluetoothctl connect "$MAC" ;;\n' +
                'esac'
        onResult: text => {
            s.sel()
            s.btBusy = ""
            if (actProc.exitCode !== 0) { const lines = text.trim().split("\n"); s.btMessage = lines[lines.length - 1] }
            s.btRefresh()
        }
    }

    // ================= Sound (wpctl, pw-dump; as in VolumeMenu and OutputList) =================
    property real volume: 0
    property bool muted: false
    property real pending: -1
    property real micVolume: 0
    property bool micMuted: false
    property real micPending: -1
    property var sinks: []           // [{ id, name, current, bt }]
    property var sources: []
    function soundRefresh() { volProc.running = true; micProc.running = true; dumpProc.running = true }
    function toggleMute(key) {
        if (key === "mic") micMuted = !micMuted; else muted = !muted
        Quickshell.execDetached(["wpctl", "set-mute", key === "mic" ? "@DEFAULT_AUDIO_SOURCE@" : "@DEFAULT_AUDIO_SINK@", "toggle"])
        soundSoon.restart()
    }
    function devIcon(d, source) {
        return d.bt || /head|buds|airpods/i.test(d.name) ? "headphones" : source ? "mic"
             : /macbook|built-in|laptop/i.test(d.name) ? "laptop" : /tv|display|monitor/i.test(d.name) ? "tv" : "speaker"
    }
    function soundRows() {
        const pct = v => Math.round(v * 100) + "%"
        const r = [{ kind: "header", name: "Output" },
                   { kind: "slider", key: "volume", name: "Volume", value: volume, dimmed: muted, extra: "mute",
                     glyph: muted || volume === 0 ? "volume-x" : volume < 0.34 ? "volume" : volume < 0.67 ? "volume-1" : "volume-2",
                     summary: muted ? "muted" : pct(volume) }]
        for (const d of sinks)
            r.push({ kind: "sounddev", id: d.id, name: d.name, glyph: devIcon(d, false), trailGlyph: d.current ? "check" : undefined, extra: "output speakers" })
        r.push({ kind: "header", name: "Microphone" },
               { kind: "slider", key: "mic", name: "Microphone", value: micVolume, dimmed: micMuted, extra: "mute input",
                 glyph: micMuted ? "mic-off" : "mic", summary: micMuted ? "muted" : pct(micVolume) })
        for (const d of sources)
            r.push({ kind: "sounddev", id: d.id, name: d.name, glyph: devIcon(d, true), trailGlyph: d.current ? "check" : undefined, extra: "input microphone" })
        r.push({ kind: "header", name: "More" })
        r.push({ kind: "action", name: "Sound settings…", glyph: "settings", cmd: ["pavucontrol"] })
        return r
    }
    Timer { interval: 1000; repeat: true; running: s.shown && s.level === "sound"; onTriggered: s.soundRefresh() }
    Timer { id: soundSoon; interval: 150; onTriggered: s.soundRefresh() }
    Timer {
        id: volApply; interval: 60
        onTriggered: {
            if (s.pending >= 0) { Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", s.pending.toFixed(2)]); s.pending = -1 }
            if (s.micPending >= 0) { Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", s.micPending.toFixed(2)]); s.micPending = -1 }
        }
    }
    Sh {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        onResult: text => {
            const r = text.match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/)
            if (!r || s.pending >= 0 || (parseFloat(r[1]) === s.volume && !!r[2] === s.muted)) return
            s.sel(); s.volume = parseFloat(r[1]); s.muted = !!r[2]
        }
    }
    Sh {
        id: micProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        onResult: text => {
            const r = text.match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/)
            if (!r || s.micPending >= 0 || (parseFloat(r[1]) === s.micVolume && !!r[2] === s.micMuted)) return
            s.sel(); s.micVolume = parseFloat(r[1]); s.micMuted = !!r[2]
        }
    }
    Sh {
        id: dumpProc
        command: ["pw-dump"]
        onResult: text => {
            let objs
            try { objs = JSON.parse(text) } catch (e) { return }
            const def = {}
            for (const ob of objs) {
                if (ob.type !== "PipeWire:Interface:Metadata") continue
                for (const e of (ob.metadata || []))
                    if ((e.key === "default.audio.sink" || e.key === "default.audio.source") && e.value) def[e.key] = e.value.name
            }
            const out = { "Audio/Sink": [], "Audio/Source": [] }
            for (const ob of objs) {
                if (ob.type !== "PipeWire:Interface:Node") continue
                const p = (ob.info || {}).props || {}
                const list = out[p["media.class"]]
                if (!list || /^easyeffects_/.test(p["node.name"])) continue   // EasyEffects' virtual device, not a real one
                const key = p["media.class"] === "Audio/Sink" ? "default.audio.sink" : "default.audio.source"
                list.push({ id: ob.id, name: p["node.description"] || p["node.name"], current: p["node.name"] === def[key], bt: /^bluez_/.test(p["node.name"]) })
            }
            // The machine's own devices first, the rest alphabetically (as in OutputList)
            const rank = n => /^MacBook Pro/i.test(n) ? 0 : /^Built-in/i.test(n) ? 1 : 2
            for (const k in out) out[k].sort((a, b) => rank(a.name) - rank(b.name) || a.name.localeCompare(b.name))
            if (JSON.stringify(out["Audio/Sink"]) === JSON.stringify(s.sinks) && JSON.stringify(out["Audio/Source"]) === JSON.stringify(s.sources)) return
            s.sel()
            s.sinks = out["Audio/Sink"]
            s.sources = out["Audio/Source"]
        }
    }

    // ================= Tailscale (as in TailscaleMenu) =================
    property bool tsRunning: LastState.tailscale
    onTsRunningChanged: LastState.tailscale = tsRunning
    property string selfIp: ""
    property string selfName: ""
    property var peers: []           // [{ host, ip, online, os }]
    property string tsMessage: ""
    property string copied: ""
    Timer { id: copiedTimer; interval: 1500; onTriggered: { s.sel(); s.copied = "" } }
    function tsRows() {
        const r = [{ kind: "systoggle", key: "tailscale", name: "Tailscale", glyph: tsRunning ? "shield-check" : "shield-off", summary: tsRunning ? "on" : "off" }]
        if (tsMessage !== "") r.push({ kind: "hint", name: tsMessage })
        if (!tsRunning) return r
        if (selfIp !== "") r.push({ kind: "header", name: "This machine" },
                                  { kind: "tsmachine", name: selfName, ip: selfIp, copy: selfIp, glyph: "laptop-minimal-check", summary: copied === selfIp ? "copied" : selfIp })
        for (const online of [true, false]) {
            const list = peers.filter(p => p.online === online)
            if (list.length === 0) continue
            r.push({ kind: "header", name: online ? "Online" : "Offline" })
            for (const p of list)
                r.push({ kind: "tsmachine", name: p.host, ip: p.ip, copy: p.ip, dimmed: !online, extra: p.ip + " " + p.os,
                         glyph: /mac|ios/i.test(p.os) ? "laptop" : /android/i.test(p.os) ? "smartphone" : "server",
                         summary: copied === p.ip ? "copied" : p.ip })
        }
        r.push({ kind: "header", name: "More" })
        r.push({ kind: "action", name: "Admin console", glyph: "external-link", cmd: ["xdg-open", "https://login.tailscale.com/admin/machines"] })
        return r
    }
    Timer { interval: 3000; repeat: true; running: s.shown && s.level === "tailscale"; onTriggered: tsProc.running = true }
    Sh {
        id: tsProc
        command: ["tailscale", "status", "--json"]
        onResult: text => {
            let j
            try { j = JSON.parse(text) } catch (e) { s.sel(); s.tsRunning = false; s.peers = []; return }
            const arr = []
            for (const k in (j.Peer || {})) {
                const p = j.Peer[k]
                arr.push({ host: p.HostName, ip: (p.TailscaleIPs || [""])[0], online: !!p.Online, os: p.OS })
            }
            arr.sort((a, b) => (b.online - a.online) || a.host.localeCompare(b.host))
            const running = j.BackendState === "Running"
            const ip = ((j.Self || {}).TailscaleIPs || [""])[0]
            if (running === s.tsRunning && ip === s.selfIp && JSON.stringify(arr) === JSON.stringify(s.peers)) return
            s.sel()
            s.tsRunning = running
            s.selfIp = ip
            s.selfName = (j.Self || {}).HostName || ""
            s.peers = arr
        }
    }
    Sh {
        id: tsToggle
        onResult: text => {
            s.sel()
            if (tsToggle.exitCode !== 0)
                s.tsMessage = /denied|operator/i.test(text) ? "Permission denied. Run once: sudo tailscale set --operator=$USER"
                                                            : text.trim().split("\n").pop()
            tsProc.running = true
        }
    }

    // ================= Status (topbar/scripts/sysinfo menu and claude-usage; as in SystemMenu and ClaudeMenu) =================
    // The rows only change when their shape does (how many temperatures, processes, usage windows); the values, and the
    // processes' names, are live (liveText), so the list doesn't jump every two seconds
    property var sysData: null       // { cpu, cores, freq, load, memUsed, memTotal, swapUsed, swapTotal, temps: [{ label, c }], top: [{ name, cpu, rss }] }
    property var usage: null         // { plan, windows: [{ key, percent, resetsAt, model }], error }
    property bool usageLoaded: false
    property string statusShape: ""
    property var statusSnap: ({ d: null, u: null })   // the data the rows were built from (statusRows reads only this)
    function updateShape() {
        const d = sysData, u = usage
        const shape = JSON.stringify([d ? d.temps.map(t => t.label) : null, d ? d.top.length : 0,
                                      u && u.windows ? u.windows.map(w => w.key + w.model) : null, u ? u.error || "" : "", u ? u.plan || "" : "", usageLoaded])
        if (shape !== statusShape) { sel(); statusShape = shape; statusSnap = { d: d, u: u } }
    }
    function gb(b) { return (b / 1073741824).toFixed(1) }
    function mb(b) { return b >= 1073741824 ? gb(b) + " GB" : Math.round(b / 1048576) + " MB" }
    function usageLabel(w) { return w.key === "session" ? "5-hour session" : w.key === "weekly" ? "Weekly" : "Weekly · " + (w.model || "model") }
    function resets(iso) {           // "resets in 1h 28m" (under 24 h) or "resets Wed 01:00"
        const t = new Date(iso)
        if (isNaN(t)) return ""
        const d = Math.round((t - new Date()) / 1000)
        if (d <= 0) return "resetting now"
        if (d < 86400) { const h = Math.floor(d / 3600), mi = Math.floor(d % 3600 / 60); return "resets in " + (h > 0 ? h + "h " : "") + mi + "m" }
        return "resets " + Qt.formatDateTime(t, "ddd HH:mm")
    }
    function statusLive(key) {
        const d = sysData
        const [k, i] = key.split(":")
        if (k === "cpu") return d ? d.cpu + "%  ·  load " + d.load.join("  ") : ""
        if (k === "mem") return d ? gb(d.memUsed) + " / " + gb(d.memTotal) + " GB" + (d.swapUsed > 0 ? "  ·  swap " + mb(d.swapUsed) : "") : ""
        if (k === "temp") return d && d.temps[i] ? d.temps[i].c + " °C" : ""
        if (k === "procname") return d && d.top[i] ? d.top[i].name : ""
        if (k === "proc") return d && d.top[i] ? d.top[i].cpu.toFixed(1) + "%  ·  " + mb(d.top[i].rss) : ""
        if (k === "usage") { const w = usage && usage.windows ? usage.windows[i] : null; return w ? w.percent + "%  ·  " + resets(w.resetsAt) : "" }
        return ""
    }
    function statusRows() {
        const d = statusSnap.d, u = statusSnap.u   // not sysData / usage: they change every two seconds
        const r = [{ kind: "header", name: "System" }]
        if (!d) r.push({ kind: "hint", name: "Loading…" })
        else {
            r.push({ kind: "stat", name: "CPU", glyph: "cpu", live: "cpu", extra: "processor load" },
                   { kind: "stat", name: "Memory", glyph: "memory-stick", live: "mem", extra: "ram swap" })
            if (d.temps.length > 0) r.push({ kind: "header", name: "Temperatures" })
            d.temps.forEach((t, i) => r.push({ kind: "stat", name: t.label, glyph: "thermometer", live: "temp:" + i, extra: "temperature" }))
            if (d.top.length > 0) r.push({ kind: "header", name: "Top processes (CPU, 1 core = 100 %)" })
            d.top.forEach((p, i) => r.push({ kind: "stat", name: p.name, liveName: "procname:" + i, glyph: "activity", live: "proc:" + i, extra: "process" }))
        }
        r.push({ kind: "header", name: "Claude usage" + (u && u.plan ? " · " + u.plan : "") })
        if (usageLoaded && (!u || !u.windows || u.windows.length === 0 || u.error))
            r.push({ kind: "hint", name: u && u.error ? u.error : "No usage data. Sign in to Claude Code (run claude) first." })
        if (u && u.windows) u.windows.forEach((w, i) => r.push({ kind: "stat", name: usageLabel(w), glyph: "gauge", live: "usage:" + i, extra: "claude usage limit" }))
        r.push({ kind: "header", name: "More" },
               { kind: "action", name: "Open Claude usage page", glyph: "external-link", cmd: ["xdg-open", "https://claude.ai/settings/usage"], extra: "claude" })
        return r
    }
    Timer { interval: 2000; repeat: true; running: s.shown && s.level === "status"; onTriggered: sysProc.running = true }
    Timer { interval: 5000; repeat: true; running: s.shown && s.level === "status"; onTriggered: claudeProc.running = true }
    Sh {
        id: sysProc
        command: ["bash", "-c", "~/.config/topbar/scripts/sysinfo menu"]
        onResult: text => { try { s.sysData = JSON.parse(text); s.updateShape() } catch (e) {} }
    }
    Sh {
        id: claudeProc
        command: [Quickshell.env("HOME") + "/.config/topbar/scripts/claude-usage"]
        onResult: text => {
            try { s.usage = JSON.parse(text) } catch (e) { s.usage = null }
            s.usageLoaded = true
            s.updateShape()
        }
    }
}
