import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Launcher (⌘Space). Player row above the search field while Deck is playing (Ctrl+Space = play/pause). Root level: Apps, Passwords, Clipboard, Screenshot, Keybindings, Settings, Install, Remove, Update, Power. Enter opens an item, Esc/Backspace (with an empty query) goes back,
// at the root level Esc closes. Up/down arrows or Ctrl+N/P/J/K move the selection.
// Apps: with an empty query, the allow-listed apps; when searching, also those hidden by sync-apps (hidden-apps.sh). See fuzzel/sync-apps, apps-allow.txt.
// ⌃Enter shows the selected app in Apps or hides it from there; a hidden app is still found by searching, and nothing is
// uninstalled (your choice, ~/.local/state/nightdrive/apps.json).
// Keybindings: read from ~/.config/hypr/SHORTCUTS.md (the same file as the ⌘⇧K cheat sheet).
// Install › Software: Fedora's packages and Flathub's apps in one search (hypr/scripts/pkg-search): apps first, one row per
// app (Fedora's if both have it), then command-line tools. Install › Software and Remove: Enter on a row opens its details
// in a wider card (hypr/scripts/pkg-info); there Enter installs or removes it, Tab takes the app from the other source,
// Esc goes back to the results.
PanelWindow {
    id: win

    // A key in the footer: Lucide glyph (Enter, Ctrl, ...) or its name (Esc). A footer part's keys share one frame (footer, below).
    component Keycap: Item {
        property string key: ""
        readonly property string glyph: win.keyGlyphs[key] || ""
        width: label.implicitWidth; height: 19
        Text {
            id: label
            anchors.centerIn: parent
            text: parent.glyph !== "" ? Icons.g(parent.glyph) : parent.key.length === 1 ? parent.key : parent.key.toLowerCase()   // a letter (⌘C) stays a capital
            color: Theme.dim
            font { family: parent.glyph !== "" ? Icons.family : Theme.font; pixelSize: parent.glyph !== "" ? 12 : 11 }
        }
    }

    // --- Tunables ---
    readonly property int iconSize: 28        // icon size (px)
    readonly property int rowHeight: 52       // row height (px)
    readonly property int maxRows: 10         // how many rows are visible at once
    readonly property int cardWidth: 660
    readonly property int fontSize: 17
    readonly property int fontWeight: Font.Light   // text weight (headers in bold)
    readonly property real topPosition: 0.189  // card top edge as a fraction of screen height (0 = top)

    property bool open: false
    property string level: "root"             // root | apps | keys
    property string query: ""
    property var syncHidden: []               // apps hidden by sync-apps: [{ path, name, icon, extra }]
    property var keyList: []                  // [{ name, sub, keys, section }]
    property var keyIndex: ({})               // lower-case name → keys (shortcutFor)
    property string armed: ""                 // action awaiting confirmation
    property var installResults: []           // Install: search results
    property string installQ: ""              // the query the results belong to
    property string webName: ""               // Install › Webapp: the name, while asking for the address
    property var emojiList: []               // Emoji: [{ ch, name, kw }] (data/emoji.tsv, CLDR names in English and Finnish)
    property bool emojiLoaded: false
    property var removeList: []               // Remove: user-installed packages
    property var detail: null                 // Install / Remove: the package row whose details are shown ({ name, summary, src, id, cmd, remove })
    property var detailInfo: null             // its details from pkg-info (null = still loading)
    readonly property int detailWidth: 860    // the card's width while showing them
    property bool removeLoaded: false
    // Settings › Launcher: { fuzzy, shortcuts } in ~/.local/state/nightdrive/launcher.json (missing = on)
    property var prefs: ({ fuzzy: true, shortcuts: true })
    readonly property string prefsFile: Quickshell.env("HOME") + "/.local/state/nightdrive/launcher.json"
    FileView {
        path: win.prefsFile; watchChanges: true; onFileChanged: reload(); printErrors: false
        onLoaded: {
            let v = {}
            try { v = JSON.parse(text()) || {} } catch (e) {}
            const n = { fuzzy: v.fuzzy !== false, shortcuts: v.shortcuts !== false }
            if (JSON.stringify(n) !== JSON.stringify(win.prefs)) win.prefs = n
        }
    }
    function setPref(key, on) {
        const n = Object.assign({}, prefs); n[key] = on
        prefs = n
        Quickshell.execDetached(["bash", "-c", 'mkdir -p "$(dirname "$2")" && printf "%s\\n" "$1" > "$2.tmp" && mv "$2.tmp" "$2"',
                                 "_", JSON.stringify(n), prefsFile])
    }
    property var pluginList: null             // Install › Plugins: [{ name, icon, desc, installed }] (nightdrive plugins), null = loading
    property var pwItems: []                  // Passwords: 1Password items (op item list)
    property string pwState: "idle"           // idle | loading | ready | error
    property string pwError: ""
    property var clipItems: []                // Clipboard: cliphist history
    property var musicAlbums: []              // Music: Deck's shelf and Curated albums [{ uri, name, artist, year, list }]
    property var spotify: null                // Music › Search: { query, artists, albums, error } (deck search --json)
    property var artist: ({ id: "", name: "", albums: null })   // Music › Search › an artist's albums
    property bool clipLoaded: false
    property var wallList: []                 // Settings › Background: [{ path, thumb, name, group, own }] (hypr/scripts/wallpaper list)
    property bool wallLoaded: false
    property string wallCurrent: ""           // current wallpaper
    property int idleSaver: -1                // Settings › Screensaver: minutes until the screensaver / screen off, 0 = never,
    property int idleOff: -1                  // -1 = not read yet (hypr/scripts/idle)
    property string idleStyle: ""             // which screensaver: random | saver | rain | clock
    // Settings › Notifications (hypr/scripts/sounds): file name, shown name, icon
    property string soundRegular: ""
    property string soundUrgent: ""
    readonly property var soundChoices: ({
        regular: [["plip", "Plip", "bell"], ["drop", "Drop", "bell"], ["tick", "Tick", "bell"], ["retro", "Retro", "bell"], ["glass", "Glass", "bell"]],
        urgent: [["double-plip", "Double plip", "bell-ring"], ["plip-fall", "Falling plip", "bell-ring"], ["synth-fall", "Synth fall", "bell-ring"],
                 ["arpeggio", "Arpeggio", "bell-ring"], ["pulse", "Pulse", "bell-ring"]]
    })
    readonly property var soundDefaults: ({ regular: "plip", urgent: "double-plip" })
    function soundName(which, v) { return v === "none" ? "none" : (soundChoices[which].find(t => t[0] === v) || [])[1] }
    readonly property var saverStyles: [["random", "Random", "shuffle"], ["saver", "Synthwave", "sunset"], ["rain", "Rain", "cloud-rain"], ["clock", "Clock", "clock"]]
    property int barOpacity: -1               // Settings › Top bar opacity: current value (hypr/scripts/bar-style), -1 = not read yet
    property string barIcons: ""              // Settings › Top bar icons: light | dark
    property int barIconOp: -1                // icon and text opacity
    property string barHl: ""                 // Settings › Top bar › Highlight: theme | white | black
    property int updates: 0                   // Update: new Nightdrive commits waiting (nightdrive update check, every 6 h)
    property var displays: null               // Settings › Display: [{ name, desc, scale, opts: [{ value, size }] }] (hypr/scripts/display list)
    property real bright: -1                  // Settings › Display › Brightness: 0..1 (brightnessctl), -1 = no backlight (a VM) or not read yet
    property real pendingBright: -1           // the slider's value waiting to be applied (throttled, like in BatteryMenu)
    property string night: ""                 // Settings › Display › Night light: on | off (hypr/scripts/nightlight status)
    property var batt: null                   // Settings › Battery: { percent, state, timeText } (upower)
    property var battDetail: null             // and its details (topbar/scripts/sysinfo battery), null on a desktop
    readonly property int brightStep: 5       // ←/→ on the brightness row, the same step as the brightness keys (hypr/scripts/brightness)
    property var themeList: []                // Settings › Theme › Color: [{ value, name, swatch, current }] (hypr/scripts/theme list)
    readonly property bool grid: level === "background"   // wallpapers as a grid, other levels as a list
    readonly property int gridCols: 2
    property var deckInfo: null               // Deck playback state (state.json): null = not playing / not running
    property bool deckAlive: false            // Deck's helper process is running
    property bool playerFocused: false        // player row is selected (up arrow from the first list row)
    // Personal additions from a private overlay: local/LauncherExtension.qml (not in the repo, see README).
    // It may add root items and whole levels; see the functions it is asked for below (extItems, activate, ...).
    property string extSource: ""             // shell.qml sets this when the file exists
    readonly property var ext: extLoader.item
    // Levels from other files: SystemLevels.qml (Wi-Fi, Bluetooth, Sound, Tailscale), HomeLevels.qml (Home Assistant) and the
    // private extension; they answer
    // the same questions (items, activate, footer, entered)
    function extOf(l) { return sys.levels.indexOf(l) >= 0 ? sys : home.levels.indexOf(l) >= 0 ? home : ext !== null && ext.levels.indexOf(l) >= 0 ? ext : null }
    readonly property bool extLevel: extOf(level) !== null
    readonly property int selIndex: list.currentIndex
    function shakeNow() { shake.restart() }
    readonly property var parents: Object.assign({ launcherprefs: "settings", shelf: "music", curated: "music", musicsearch: "music", artist: "musicsearch", display: "settings", battery: "settings", install: "system", remove: "system", emoji: "tools", screenshot: "tools", software: "install", webapp: "install", plugins: "install", webname: "webapp", webaddr: "webname", theme: "settings", themecolor: "theme", background: "theme", topbar: "settings", startup: "settings", screensaver: "settings", saverafter: "screensaver", screenoff: "screensaver", saverstyle: "screensaver", sounds: "settings", soundregular: "sounds", soundurgent: "sounds", baropacity: "topbar", baricons: "topbar", barhl: "topbar", baritems: "topbar" }, sys.parents, home.parents, ext ? ext.parents : {})
    // Search found nothing: hint below ⌘⌥⏎ (icons) → send the text to Claude
    readonly property bool noHit: (level === "root" || level === "apps") && query.trim() !== "" && results.length === 0
    // The selected row is an app: ⌃Enter shows it in Apps (the list with an empty query) or hides it from there.
    // "Hide", not "remove": removing sounded like uninstalling.
    readonly property var selApp: { const c = results[list.currentIndex]; return (level === "apps" || level === "root") && c && c.kind === "app" ? c : null }
    readonly property string footer: detail !== null ? (detail.remove ? "Enter: remove" : detailInfo && detailInfo.installed ? "Already installed" : "Enter: install")
                                                       + (detail.alt ? "  ·  Tab: get it from " + (detail.alt.src === "flatpak" ? "Flathub" : "Fedora") : "")
                                                       + "  ·  Esc: back"
        : selApp ? "Enter: open  ·  Ctrl+Enter: " + (selApp.shown ? "hide from Apps" : "show in Apps")
                                              + "  ·  Alt+Enter: " + (autostartIds.indexOf(appId(selApp)) >= 0 ? "don’t start at login" : "start at login")
        : level === "launcherprefs" ? "Enter: on/off"
        : level === "startup" ? "Enter: start at login on/off  ·  background apps start hidden"
        : (results[list.currentIndex] || {}).kind === "brightness" ? "Left+Right: brightness"
        : (results[list.currentIndex] || {}).kind === "mirrordev" ? sys.footer(level, query)
        : (results[list.currentIndex] || {}).kind === "haent" ? home.footer(level, query)
        : (results[list.currentIndex] || {}).kind === "nightlight" ? "Enter: night light on/off"
        : (results[list.currentIndex] || {}).kind === "sound" ? "Enter: choose  ·  Shift+Enter: listen"
        : level === "baritems" ? "Enter: show / hide  ·  Ctrl+Up+Down: reorder"
        : level === "passwords" && pwState === "ready" ? "Enter: password  ·  Shift+Enter: username  ·  Ctrl+Enter: one-time code"
        : extOf(level) ? extOf(level).footer(level, query)   // not extLevel: it can lag a level change by one update
        : level === "clipboard" ? "Enter: paste  ·  Shift+Enter: copy only"
        : level === "shelf" || level === "curated" ? "Enter: play in Deck"
        : level === "emoji" ? "Enter: paste  ·  Shift+Enter: copy only  ·  search in English or Finnish"
        : level === "plugins" && (results[list.currentIndex] || {}).kind === "action" ? ((results[list.currentIndex] || {}).installed ? "Enter: run the installer again" : "Enter: install in a terminal")
        : level === "webname" && query.trim() !== "" ? "Enter: continue to the address"
        : level === "webaddr" && query.trim() !== "" ? "Enter: create the webapp" : ""
    // The footer as key caps: "Ctrl+Enter: show in Apps  ·  Esc: back" → [{ keys: ["Ctrl", "Enter"], text: "show in Apps" }, ...].
    // "Enter creates …" (no colon) works too; a part that doesn't start with a key is plain text.
    readonly property var keyGlyphs: ({ Enter: "corner-down-left", Ctrl: "chevron-up", Shift: "arrow-big-up", Alt: "option", Cmd: "command",
                                        Up: "arrow-up", Down: "arrow-down", Left: "arrow-left", Right: "arrow-right",
                                        Backspace: "delete", Space: "space" })
    readonly property var footerParts: footer === "" ? [] : footer.split(/\s+·\s+/).map(part => {
        const m = part.match(/^((?:Ctrl|Shift|Alt|Cmd|Enter|Esc|Tab|Space|Backspace|Up|Down|Left|Right)(?:\+(?:Ctrl|Shift|Alt|Cmd|Enter|Esc|Tab|Space|Backspace|Up|Down|Left|Right|[A-Z]))*)(?::\s*|\s+)(.*)$/)
        return m ? { keys: m[1].split("+"), text: m[2] } : { keys: [], text: part }
    })
    property var lastMouse: null              // last mouse position (window coordinates); null = not seen yet since opening
    property var deckOverride: ({})           // pending local changes (playing, liked)
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts"
    readonly property string deckBin: Quickshell.env("HOME") + "/.local/bin/deck"
    readonly property bool deckPlaying: deckOverride.playing !== undefined ? deckOverride.playing : (deckInfo !== null && deckInfo.playing)
    readonly property var deckLiked: deckOverride.liked !== undefined ? deckOverride.liked : (deckInfo ? deckInfo.liked : null)
    signal openMenu(string name)              // Settings: opens a Quickshell menu (wifi, bluetooth, ...)

    readonly property var titles: Object.assign({ apps: "Apps", music: "Music", shelf: "Music › Album Shelf", curated: "Music › Curated", musicsearch: "Music › Search", artist: "Music › " + artist.name, keys: "Keybindings", screenshot: "Tools › Screenshot", settings: "Settings", display: "Settings › Display", battery: "Settings › Battery", startup: "Settings › Startup", screensaver: "Settings › Screensaver", saverafter: "Screensaver › Start after", screenoff: "Screensaver › Screen off after", saverstyle: "Screensaver › Style", sounds: "Settings › Notifications", soundregular: "Notifications › Regular sound", soundurgent: "Notifications › Urgent sound", theme: "Settings › Theme", themecolor: "Settings › Theme › Color", background: "Settings › Theme › Background",
                                     launcherprefs: "Settings › Launcher", topbar: "Settings › Top bar", baropacity: "Top bar › Opacity", baricons: "Top bar › Icon colors", barhl: "Top bar › Highlight", baritems: "Top bar › Items",
                                     system: "System", install: "System › Install", emoji: "Tools › Emoji", software: "Install › Software", webapp: "Install › Webapp", plugins: "Install › Plugins", webname: "Install › Webapp › Name", webaddr: "Install › Webapp › Address", remove: "System › Remove", power: "Power", passwords: "Passwords", clipboard: "Clipboard",
                                     tools: "Tools" }, sys.titles, home.titles, ext ? ext.titles : {})

    // Reference at startup: the app list only loads on first reference
    property var apps: DesktopEntries.applications.values

    // Terminal window that runs a command and waits for Enter (sudo asks for the password here)
    function term(script, arg) {
        return ["kitty", "--class", "floating-tui", "-e", "bash", "-c",
                script + "; echo; read -rp 'Done. Press Enter to close…'", "_", arg || ""]
    }
    function webappTerm() {
        return term('read -rp "Name: " n; read -rp "Address: " u; "$HOME/.config/hypr/scripts/webapp-add" "$n" "$u"')
    }
    function shot(mode) { return ["bash", "-c", "sleep 0.4; \"$HOME/.config/hypr/scripts/screenshot\" \"$1\"", "_", mode] }

    readonly property var rootItems: [
        { kind: "nav", name: "Apps", glyph: "layout-grid", target: "apps" },
        { kind: "nav", name: "Passwords", glyph: "key-round", target: "passwords" },
        { kind: "nav", name: "Clipboard", glyph: "clipboard-list", target: "clipboard" },
        { kind: "nav", name: "Music", glyph: "disc-3", target: "music" },
    ].concat(home.rootItems, ext ? ext.rootItems : [], [
        { kind: "nav", name: "Tools", glyph: "wrench", target: "tools" },
        { kind: "nav", name: "Keybindings", glyph: "keyboard", target: "keys" },
        { kind: "nav", name: "Settings", glyph: "settings", target: "settings" },
        // System: Install, Remove, Update and Status (the update count shows here too)
        { kind: "nav", name: "System", glyph: "monitor-cog", target: "system", summary: updates > 0 ? updates + " new" : undefined },
        { kind: "nav", name: "Power", glyph: "power", target: "power" }
    ])

    // Static sublevels
    readonly property var statics: ({
        system: [
            { kind: "nav", name: "Install", glyph: "package-plus", target: "install", extra: "software package app flatpak dnf" },
            { kind: "nav", name: "Remove", glyph: "package-minus", target: "remove", extra: "uninstall delete package app" },
            { kind: "action", name: "Update", glyph: "refresh-cw", confirm: true, cmd: term('"$HOME/.local/bin/nightdrive" update'),
              summary: updates > 0 ? updates + " new" : undefined, extra: "upgrade dnf flatpak nightdrive" },
            { kind: "nav", name: "Status", glyph: "activity", target: "status", extra: "cpu memory processes temperature claude usage" }
        ],
        tools: [
            { kind: "nav", name: "Screenshot", glyph: "camera", target: "screenshot" },
            { kind: "nav", name: "Emoji", glyph: "smile", target: "emoji" },
            { kind: "action", name: "Color Picker", glyph: "pipette", cmd: ["bash", "-c", "sleep 0.4; \"$HOME/.config/hypr/scripts/color-picker\""] }
        ],
        screenshot: [
            { kind: "action", name: "Region", glyph: "crop", cmd: shot("region") },
            { kind: "action", name: "Window", glyph: "app-window", cmd: shot("window") },
            { kind: "action", name: "Full screen", glyph: "monitor", cmd: shot("full") }
        ],
        install: [
            { kind: "nav", name: "Software", glyph: "package-plus", target: "software", summary: "dnf + Flatpak" },
            { kind: "nav", name: "Webapp", glyph: "app-window", target: "webapp", summary: "website as an app" },
            { kind: "nav", name: "Plugins", glyph: "puzzle", target: "plugins", summary: "optional parts" }
        ],
        webapp: [
            { kind: "nav", name: "Name and address here", glyph: "keyboard", target: "webname" },
            { kind: "action", name: "In a terminal", glyph: "terminal", cmd: webappTerm() }
        ],
        // In groups like macOS's System Settings: the often used first (connections, hardware), then the look, then
        // what is set once (behaviour)
        settings: [
            { kind: "header", name: "Connections" },
            { kind: "nav", name: "Wi-Fi", glyph: "wifi", target: "wifi" },
            { kind: "nav", name: "Bluetooth", glyph: "bluetooth", target: "bluetooth" },
            { kind: "nav", name: "Tailscale", glyph: "shield-check", target: "tailscale" },
            { kind: "header", name: "Hardware" },
            { kind: "nav", name: "Sound", glyph: "volume-2", target: "sound" },
            { kind: "nav", name: "Display", glyph: "monitor", target: "display" },
            { kind: "nav", name: "Battery", glyph: "battery-medium", target: "battery" },
            { kind: "header", name: "Appearance" },
            { kind: "nav", name: "Theme", glyph: "palette", target: "theme" },
            { kind: "nav", name: "Top bar", glyph: "panel-top", target: "topbar" },   // its look and what it shows
            { kind: "nav", name: "Screensaver", glyph: "monitor-pause", target: "screensaver" },
            { kind: "header", name: "Behaviour" },
            { kind: "nav", name: "Launcher", glyph: "text-search", target: "launcherprefs" },
            { kind: "nav", name: "Notifications", glyph: "bell-ring", target: "sounds" },
            { kind: "nav", name: "Startup", glyph: "rocket", target: "startup" }
        ],
        power: [
            { kind: "action", name: "Lock", glyph: "lock", cmd: ["loginctl", "lock-session"] },
            { kind: "action", name: "Sleep", glyph: "moon", cmd: ["systemctl", "suspend"] },
            { kind: "action", name: "Log out", glyph: "log-out", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
            { kind: "action", name: "Restart", glyph: "rotate-cw", confirm: true, cmd: ["systemctl", "reboot"] },
            { kind: "action", name: "Shut down", glyph: "power", confirm: true, cmd: ["systemctl", "poweroff"] }
        ]
    })

    readonly property var settingsAliases: ({ "Wi-Fi": "wifi wlan network internet", "Sound": "audio volume output speakers", "Battery": "power charge charging health cycles",
                                              "Display": "brightness night light warm scale scaling resolution monitor screen retina hidpi zoom size bigger smaller",
                                              "Notifications": "notification sounds alert chime beep ping tone urgent critical",
                                              "Tailscale": "vpn", "Theme": "appearance style look colors",
                                              "Color": "theme accent violet purple blue teal green amber rose graphite gray",
                                              "Background": "wallpaper desktop image picture",
                                              "Top bar": "waybar panel menu bar",
                                              "Launcher": "search fuzzy typos shortcuts hints spotlight",
                                              "Opacity": "top bar waybar panel transparency transparent",
                                              "Icon colors": "top bar waybar panel white black light dark text",
                                              "Highlight": "top bar waybar panel active workspace",
                                              "Items": "top bar panel modules icons show hide clock date battery",
                                              "Brightness": "screen dim dimmer brighter backlight",
                                              "Night light": "night shift warm yellow blue light evening",
                                              "Scale": "scaling resolution monitor screen retina hidpi zoom size bigger smaller",
                                              "Screen Mirroring": "airplay cast mirror apple tv share screen" })
    // Settings › Theme: sub-items (Color with its current value)
    function themeItems() {
        const cur = themeList.find(t => t.current)
        return [
            { kind: "nav", name: "Color", glyph: "palette", target: "themecolor", summary: cur ? cur.name.toLowerCase() : undefined },
            { kind: "nav", name: "Background", glyph: "wallpaper", target: "background" }
        ]
    }
    // Settings › Screensaver: the two idle times with their current values, and a preview
    function minutes(m) { return m < 0 ? undefined : m === 0 ? "never" : m + " min" }
    function screensaverItems() {
        return [
            { kind: "nav", name: "Style", glyph: "sparkles", target: "saverstyle", summary: (saverStyles.find(t => t[0] === idleStyle) || [])[1] },
            { kind: "nav", name: "Start after", glyph: "timer", target: "saverafter", summary: minutes(idleSaver) },
            { kind: "nav", name: "Screen off after", glyph: "monitor-off", target: "screenoff", summary: minutes(idleOff) },
            { kind: "action", name: "Preview", glyph: "monitor-play", cmd: ["bash", "-c", "sleep 0.4; \"$HOME/.config/screensaver/start\""] }
        ]
    }
    // Settings › Notifications: the two choices with their current sound
    function soundsItems() {
        return [
            { kind: "nav", name: "Regular sound", glyph: "bell", target: "soundregular", summary: soundName("regular", soundRegular) },
            { kind: "nav", name: "Urgent sound", glyph: "bell-ring", target: "soundurgent", summary: soundName("urgent", soundUrgent) }
        ]
    }
    // Settings › Display for the root search: the brightness slider row itself (←/→ work there too), the night light toggle
    // and Scale (opens Display)
    function displayItems() {
        return (bright >= 0 ? [{ kind: "brightness", name: "Brightness", glyph: "sun" }] : [])
            .concat([{ kind: "nightlight", name: "Night light", glyph: "moon" },
                     { kind: "nav", name: "Scale", glyph: "monitor", target: "display" }],
                    sys.mirrorAvail ? [{ kind: "nav", name: "Screen Mirroring", glyph: "screen-share", target: "display" }] : [])
    }
    // Settings › Top bar: sub-items with their current values
    function topbarItems() {
        return [
            { kind: "nav", name: "Opacity", glyph: "panel-top", target: "baropacity", summary: barOpacity >= 0 ? barOpacity + "%" : undefined },
            { kind: "nav", name: "Icon colors", glyph: "contrast", target: "baricons",
              summary: barIcons !== "" ? (barIcons === "dark" ? "black" : "white") + " " + barIconOp + "%" : undefined },
            { kind: "nav", name: "Highlight", glyph: "highlighter", target: "barhl",
              summary: barHl === "theme" ? "theme color" : (barHl || undefined) },
            { kind: "nav", name: "Items", glyph: "layout-list", target: "baritems",
              summary: TopBar.modules.length + " of " + TopBar.allModules.length + " shown" }
        ]
    }
    readonly property var installAliases: ({ "Software": "package dnf rpm flatpak flathub app apps program store",
                                             "Webapp": "web app website site pwa url",
                                             "Plugins": "plugin extension addon optional home assistant jottacloud deck vscode airplay" })
    readonly property var powerAliases: ({ "Lock": "screen", "Sleep": "suspend", "Log out": "logout sign out exit", "Restart": "reboot", "Shut down": "shutdown poweroff power off" })

    // Lower case without diacritics: "keittio" finds Keittiö, "ylavalo" Ylävalo
    function fold(s) { return s.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "") }
    // 0 = starts with query, 1 = word start, 2 = contains, -1 = no match (q folded)
    function score(text, q) {
        const t = fold(text)
        if (t.startsWith(q)) return 0
        if (t.split(/[\s\-_.\/]+/).some(w => w.startsWith(q))) return 1
        if (t.includes(q)) return 2
        return -1
    }
    // The last tier: q's letters in order, but not just anywhere (that would match nearly everything). Each letter is at a
    // word start, right after the previous match, or a letter or two after it in the same word: "vsc" → Visual Studio
    // Code, "kattovlo" → Kattovalo. Both folded.
    function fuzzy(t, q) {
        const start = i => i === 0 || /[\s\-_.\/›:]/.test(t[i - 1])
        const from = (qi, ti) => {        // q[qi..] matches from t[ti..]; prev match at ti - 1
            if (qi === q.length) return true
            for (let i = ti; i < t.length; i++) {
                if (t[i] !== q[qi]) continue
                const gap = i - ti
                const ok = qi === 0 ? start(i) : gap === 0 || start(i) || (gap <= 2 && !/[\s\-_.\/›:]/.test(t.slice(ti, i)))
                if (ok && from(qi + 1, i + 1)) return true
            }
            return false
        }
        return q.length >= 2 && from(0, 0)
    }

    // Groups keybindings by section (sections in file order) and adds header rows
    function grouped(list) {
        const by = {}
        for (const it of list) (by[it.section] = by[it.section] || []).push(it)
        const out = []
        const seen = {}
        for (const k of keyList) {
            if (seen[k.section] || !by[k.section]) continue
            seen[k.section] = true
            out.push({ kind: "header", name: k.section })
            for (const it of by[k.section]) out.push(it)
        }
        return out
    }
    function firstSelectable() {
        for (let i = 0; i < results.length; i++) if (results[i].kind !== "header") return i
        return 0
    }
    // Moves the selection, skipping header rows
    function step(dir) {
        let i = list.currentIndex + dir
        while (i >= 0 && i < results.length && results[i].kind === "header") i += dir
        if (i < 0 && dir < 0) { playerFocused = true; return }       // up from the top of the list: player row
        if (i >= 0 && i < results.length) {
            list.currentIndex = i
            // Up onto a section's first row: its header comes into view too (the list only scrolls to the row itself)
            if (dir < 0 && i > 0 && results[i - 1].kind === "header") Qt.callLater(() => list.positionViewAtIndex(i - 1, ListView.Contain))
        }
    }
    readonly property int headerHeight: 40
    function listHeight() {
        const cap = maxRows * rowHeight
        let h = 0
        for (const it of results) {
            h += it.kind === "header" ? headerHeight : rowHeight
            if (h >= cap) return cap
        }
        return h
    }

    function hint(text) { return [{ kind: "hint", name: text }] }

    // App rows: with an empty query only allow-listed apps; when searching, also those hidden by sync-apps
    function appEntries(q) {
        const all = apps.filter(e => !e.noDisplay).map(e => ({
            item: { kind: "app", name: e.name, icon: e.icon, entry: e, shown: true },
            text: e.name,
            extra: (e.genericName || "") + " " + (e.keywords || []).join(" ")
        }))
        if (q !== "") for (const h of syncHidden) all.push({ item: { kind: "app", name: h.name, icon: h.icon, path: h.path, shown: false }, text: h.name, extra: h.extra })
        // An app just moved with ⌃Enter: the two sources (DesktopEntries, hidden-apps.sh) update at different moments, so
        // until its new place shows up the row is kept from the snapshot, and its old place is left out
        const out = all.filter(a => { const p = pinPending[appId(a.item)]; return !p || p.shown === a.item.shown })
        for (const id in pinPending) {
            const p = pinPending[id]
            if (!out.some(a => appId(a.item) === id) && (p.shown || q !== "")) out.push({ item: p, text: p.name, extra: "" })
        }
        return out
    }

    function items() {
        const q = query.trim().toLowerCase()
        let all
        if (level === "root") {
            all = rootItems.map(r => ({ item: r, text: r.name, extra: r.extra || "" }))
            // When searching, the root level also finds rows from the sublevels, so there's no need to open a menu first.
            // "from" tells which menu a row comes from; extra adds search words (aliases, alternative spellings).
            if (q !== "") for (const src of [
                // Tools entries ("color" → Color Picker)
                statics.tools.map(t => ({ item: t, text: t.name })),
                // Screenshot actions ("region", "screenshot", "capture")
                statics.screenshot.map(t => ({ item: Object.assign({}, t, { from: "Screenshot" }), text: t.name, extra: "screenshot capture screen" })),
                // Settings items ("wallpaper" → Background, "wifi" → Wi-Fi) plus Theme and Top bar sub-items ("opacity")
                statics.settings.filter(t => t.kind !== "header").map(t => ({ item: Object.assign({}, t, { from: "Settings" }), text: t.name, extra: "settings " + (settingsAliases[t.name] || "") })),
                themeItems().map(t => ({ item: Object.assign({}, t, { from: "Theme", summary: undefined }), text: t.name, extra: "theme " + (settingsAliases[t.name] || "") })),
                topbarItems().map(t => ({ item: Object.assign({}, t, { from: "Top bar", summary: undefined }), text: t.name, extra: settingsAliases[t.name] || "" })),
                // Display and Screensaver sub-items ("night" → Night light, "dim" → Brightness, "saver" → Start after)
                displayItems().map(t => ({ item: Object.assign({}, t, { from: "Display" }), text: t.name, extra: "display " + (settingsAliases[t.name] || "") })),
                // Screen Mirroring's receivers ("mirror", "airplay", "olohuone"): Enter starts mirroring right from the search
                sys.mirrorRows().filter(t => t.kind === "mirrordev").map(t => ({ item: Object.assign({}, t, { from: "Screen Mirroring", summary: undefined }),
                                                                                  text: t.name, extra: "screen mirroring " + t.extra })),
                // AirPlay speakers ("airplay", "olohuone"): Enter makes it the sound output
                sys.sinks.filter(d => d.airplay).map(d => ({ item: { kind: "sounddev", id: d.id, name: d.name, glyph: "speaker", from: "Sound",
                                                                     trailGlyph: d.current ? "check" : undefined },
                                                             text: d.name, extra: "airplay sound audio output speaker" })),
                screensaverItems().map(t => ({ item: Object.assign({}, t, { from: "Screensaver", summary: undefined }), text: t.name, extra: "screensaver idle lock" })),
                // System's items ("upd" → Update, "cpu" → Status)
                statics.system.map(t => ({ item: Object.assign({}, t, { from: "System", summary: undefined }), text: t.name, extra: t.extra || "" })),
                // Install's sub-items ("flatpak", "webapp", "flathub" → Flatpak)
                statics.install.map(t => ({ item: Object.assign({}, t, { from: "Install", summary: undefined }), text: t.name,
                                            extra: "install " + (installAliases[t.name] || "") })),
                // Power actions ("shut" → Shut down)
                statics.power.map(t => ({ item: t, text: t.name, extra: powerAliases[t.name] || "" })),
                // Apps ("1pas" → 1Password), also one named like a root item (e.g. a webapp next to its menu): the APPS tag and
                // the open-window dot tell them apart
                appEntries(q).map(a => Object.assign({}, a, { item: Object.assign({}, a.item, { from: "Apps" }) })),
                // Home Assistant's devices ("olohuone" → its lights): Enter turns one on/off right from the search
                home.rootRows(),
                // Deck's albums ("fm-84" → Atlas)
                // (the MUSIC tag on the right instead of the year)
                musicAlbums.map(a => ({ item: Object.assign(albumItem(a), { summary: undefined, from: "Music" }), text: a.name, extra: a.artist }))
            ]) all = all.concat(src)
        } else if (level === "apps") {
            all = appEntries(q)
            if (q === "") all.sort((a, b) => a.text.localeCompare(b.text))
        } else if (level === "keys") {
            all = keyList.map(k => ({ item: { kind: "key", name: k.name, sub: k.sub || undefined, keys: k.keys, section: k.section }, text: k.name,
                                      extra: k.keys + " " + k.section + " " + k.sub }))
        } else if (level === "software") {
            if (q.replace(/[^a-z0-9._+\-]/g, "").length < 2) return [{ kind: "hint", name: "Type at least 2 characters to search apps and tools" }]
            if (installResults.length === 0) return [{ kind: "hint", name: searchProc.running ? "Searching…" : "Nothing found" }]
            return installResults
        } else if (level === "emoji") {
            if (!emojiLoaded) return [{ kind: "hint", name: "Loading emoji…" }]
            all = emojiList.map(e => ({ item: { kind: "emoji", name: e.name, emoji: e.ch }, text: e.name, extra: e.kw }))
        } else if (level === "webname") {
            if (query.trim() === "") return hint("Type the webapp’s name")
            return [{ kind: "wname", name: "Name: " + query.trim(), summary: "next: address", glyph: "arrow-right", value: query.trim() }]
        } else if (level === "webaddr") {
            if (query.trim() === "") return hint("Type the address for “" + webName + "” (e.g. web.whatsapp.com)")
            return [{ kind: "wadd", name: "Add “" + webName + "”", summary: query.trim(), glyph: "app-window", value: query.trim() }]
        } else if (extOf(level)) {
            const r = extOf(level).items(level, q)
            if (!r.all) return r          // ready-made rows (hints, etc.)
            all = r.all                   // [{ item, text, extra }], filtered by the query below
        } else if (level === "music") {
            const count = list => musicAlbums.filter(a => a.list === list).length
            all = [{ kind: "nav", name: "Album Shelf", glyph: "library-big", target: "shelf", summary: String(count("shelf")) },
                   { kind: "nav", name: "Curated", glyph: "sparkles", target: "curated", summary: String(count("curated")) },
                   { kind: "nav", name: "Search Spotify", glyph: "search", target: "musicsearch", summary: "in Deck" }]
                .map(r => ({ item: r, text: r.name }))
        } else if (level === "musicsearch") {
            // Results come from `deck search --json` a moment after typing stops; going back from an artist shows them again
            const typed = query.trim()
            const shown = typed !== "" ? typed : (spotify ? spotify.query : "")
            if (shown === "") return hint("Type an artist or album")
            const inDeck = { kind: "decksearch", name: "Open “" + shown + "” in Deck", glyph: "external-link", value: shown }
            if (!spotify || spotify.query !== shown) return hint("Searching Spotify…")
            if (spotify.error) return hint(spotify.error).concat([inDeck])
            const artists = spotify.artists.slice(0, 4).map(a => ({ kind: "spotifyartist", name: a.name, glyph: "mic-vocal", id: a.id, chevron: true }))
            const albums = spotify.albums.map(albumItem)
            if (artists.length + albums.length === 0) return hint("Nothing found on Spotify").concat([inDeck])
            return (artists.length ? [{ kind: "header", name: "Artists" }].concat(artists) : [])
                .concat(albums.length ? [{ kind: "header", name: "Albums" }].concat(albums) : [], [inDeck])
        } else if (level === "artist") {
            if (artist.albums === null) return hint("Loading albums…")
            if (artist.albums.length === 0) return hint("No albums found")
            all = artist.albums.map(a => ({ item: albumItem(a, false), text: a.name, extra: String(a.year || "") }))
        } else if (level === "shelf" || level === "curated") {
            const albums = musicAlbums.filter(a => a.list === level)
            if (albums.length === 0) return hint(level === "shelf" ? "The shelf is empty: add albums in Deck with a"
                                                                  : "No Curated list yet: `deck curate` suggests albums based on what you play")
            all = albums.map(a => ({ item: albumItem(a), text: a.name, extra: a.artist + " " + (a.year || "") }))
        } else if (level === "clipboard") {
            if (!clipLoaded) return [{ kind: "hint", name: "Loading clipboard history…" }]
            if (clipItems.length === 0) return [{ kind: "hint", name: "Clipboard history is empty" }]
            all = clipItems.map(c => ({ item: c, text: c.name }))
        } else if (level === "background") {
            if (!wallLoaded) return [{ kind: "hint", name: "Loading backgrounds… (first time creates previews)" }]
            // "Add new…" first: file picker (hypr/scripts/wallpaper add), images are copied to ~/Pictures/Wallpapers
            all = [{ item: { kind: "walladd", name: "Add new…" }, text: "Add new", extra: "import file" }]
                .concat(wallList.map(w => ({ item: Object.assign({ kind: "wall" }, w), text: w.name, extra: w.group })))
        } else if (level === "baropacity") {
            // Number in the query → exactly that value; otherwise 100–0 in steps of ten. Current one marked.
            const n = parseInt(query.trim(), 10)
            const vals = /^\d+$/.test(query.trim()) && n <= 100 ? [n] : [100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 0]
            return vals.map(v => ({ kind: "baropacity", value: v, name: v + "%", glyph: v === barOpacity ? "check" : "panel-top",
                                    summary: v === barOpacity ? "current" : (v === 100 ? "opaque" : v === 0 ? "transparent" : undefined) }))
        } else if (level === "display") {
            // Two sections: Brightness (a slider row, when there is a backlight) and Scale
            if (displays === null) return hint("Loading…")
            const out = bright < 0 ? [] : [{ kind: "header", name: "Brightness" },
                                           { kind: "brightness", name: "Screen", glyph: "sun", summary: Math.round(bright * 100) + "%" }]
            if (night !== "") {
                if (bright < 0) out.push({ kind: "header", name: "Brightness" })
                out.push({ kind: "nightlight", name: "Night light", glyph: "moon", summary: night })
            }
            // Scales the panel divides evenly, shown as the resulting desktop size ("looks like" in macOS); current one marked
            out.push(...sys.mirrorRows())   // Screen Mirroring (AirPlay; SystemLevels.qml), empty without doubletake
            for (const d of displays) {
                out.push({ kind: "header", name: "Scale" + (displays.length > 1 ? " · " + d.name + (d.desc !== "-" ? "  " + d.desc : "") : "") })
                for (const o of d.opts) {
                    const cur = Math.abs(o.value - d.scale) < 0.01
                    out.push({ kind: "scale", output: d.name, value: o.value, name: o.size, glyph: cur ? "check" : "monitor",
                               summary: (cur ? "current · " : "") + "scale " + +o.value.toFixed(2) })
                }
            }
            return out
        } else if (level === "battery") {
            // The same as the top bar's battery menu: charge and state, then the details
            if (batt === null) return hint("Loading…")
            const b = battDetail
            const stateText = { discharging: "Discharging", charging: "Charging", "fully-charged": "Fully charged", "pending-charge": "Not charging" }[batt.state] || batt.state
            const rows = [{ kind: "stat", name: batt.percent + "%  " + stateText,
                            glyph: batt.state === "charging" ? "battery-charging" : batt.percent < 40 ? "battery-low" : batt.percent < 60 ? "battery-medium" : "battery-full",
                            summary: batt.timeText !== "" ? batt.timeText + (batt.state === "charging" ? " until full" : " remaining") : undefined }]
            if (b) {
                rows.push({ kind: "header", name: "Details" })
                for (const r of [["zap", "Power", b.watts > 0 ? b.watts + " W" : ""],
                                 ["thermometer", "Temperature", b.temp !== null ? b.temp + " °C" : ""],
                                 ["heart-pulse", "Health", b.health !== null ? b.health + "% · " + b.fullWh + " / " + b.designWh + " Wh" : ""],
                                 ["repeat", "Cycles", b.cycles !== null ? String(b.cycles) : ""],
                                 ["activity", "Voltage", b.volts !== null ? b.volts.toFixed(2) + " V" : ""],
                                 ["calendar", "Manufactured", b.made]])
                    if (r[2] !== "") rows.push({ kind: "stat", glyph: r[0], name: r[1], summary: r[2] })
            }
            return rows
        } else if (level === "theme") {
            all = themeItems().map(t => ({ item: t, text: t.name, extra: settingsAliases[t.name] || "" }))
        } else if (level === "themecolor") {
            if (themeList.length === 0) return [{ kind: "hint", name: "Loading…" }]
            all = themeList.map(t => ({ item: { kind: "themecolor", value: t.value, name: t.name, swatch: t.swatch,
                                               summary: t.current ? "current" : (t.value === "violet" ? "default" : undefined) }, text: t.name }))
        } else if (level === "screensaver") {
            all = screensaverItems().map(t => ({ item: t, text: t.name }))
        } else if (level === "sounds") {
            all = soundsItems().map(t => ({ item: t, text: t.name }))
        } else if (level === "soundregular" || level === "soundurgent") {
            const which = level === "soundregular" ? "regular" : "urgent"
            const cur = which === "regular" ? soundRegular : soundUrgent
            return soundChoices[which].concat([["none", "None", "bell-off"]]).map(t => ({ kind: "sound", which: which, value: t[0], name: t[1],
                glyph: t[0] === cur ? "check" : t[2], summary: t[0] === cur ? "current" : (t[0] === soundDefaults[which] ? "default" : undefined) }))
        } else if (level === "saverstyle") {
            return saverStyles.map(t => ({ kind: "idlestyle", value: t[0], name: t[1], glyph: t[0] === idleStyle ? "check" : t[2],
                                           summary: t[0] === idleStyle ? "current" : (t[0] === "random" ? "default" : undefined) }))
        } else if (level === "saverafter" || level === "screenoff") {
            const cur = level === "saverafter" ? idleSaver : idleOff
            const vals = level === "saverafter" ? [2, 5, 10, 15, 20, 30, 60, 0] : [5, 10, 15, 20, 30, 45, 60, 0]
            return vals.map(v => ({ kind: level === "saverafter" ? "idlesaver" : "idleoff", value: v, name: minutes(v),
                                    glyph: v === cur ? "check" : (level === "saverafter" ? "timer" : "monitor-off"), summary: v === cur ? "current" : undefined }))
        } else if (level === "topbar") {
            all = topbarItems().map(t => ({ item: t, text: t.name, extra: settingsAliases[t.name] || "" }))
        } else if (level === "baritems") {
            // What the bar shows, in its order (left to right); Enter turns one on or off
            all = TopBar.allModules.map(m => {
                const on = TopBar.hidden.indexOf(m.name) < 0
                return { item: { kind: "baritem", value: m.name, name: TopBar.moduleLabel(m), glyph: TopBar.moduleGlyph(m),
                                 trailGlyph: on ? "check" : "minus", dimmed: !on }, text: TopBar.moduleLabel(m), extra: m.name }
            })
            if (q === "") return all.map(x => x.item)      // a fixed order: toggling doesn't move rows
        } else if (level === "barhl") {
            return [["theme", "Theme color"], ["white", "White"], ["black", "Black"]].map(h => ({
                kind: "barhl", value: h[0], name: h[1], glyph: barHl === h[0] ? "check" : "highlighter",
                summary: barHl === h[0] ? "current" : (h[0] === "theme" ? "default" : undefined) }))
        } else if (level === "baricons") {
            const ops = [100, 90, 85, 80, 70, 60, 50]
            return [{ kind: "header", name: "Color" },
                    { kind: "baricons", value: "light", name: "White", glyph: barIcons === "light" ? "check" : "sun", summary: barIcons === "light" ? "current" : undefined },
                    { kind: "baricons", value: "dark", name: "Black", glyph: barIcons === "dark" ? "check" : "moon", summary: barIcons === "dark" ? "current" : undefined },
                    { kind: "header", name: "Opacity" }]
                .concat(ops.map(v => ({ kind: "bariconop", value: v, name: v + "%", glyph: v === barIconOp ? "check" : "contrast",
                                        summary: v === barIconOp ? "current" : undefined })))
        } else if (level === "passwords") {
            if (pwState === "loading" && pwItems.length === 0) return [{ kind: "hint", name: "Waiting for 1Password… (unlock it if prompted; Esc closes this menu)" }]
            if (pwState === "error") return pwError.split("\n").filter(l => l.trim() !== "").slice(0, 4).map(l => ({ kind: "hint", name: l }))
            all = pwItems.map(p => ({ item: p, text: p.name, extra: p.summary + " " + p.urls }))
        } else if (level === "startup") {
            all = appEntries(q).map(a => {
                const on = autostartIds.indexOf(appId(a.item)) >= 0
                return Object.assign({}, a, { item: Object.assign({}, a.item, { summary: on ? (bgApps[a.item.name] !== undefined ? "at login, hidden" : "at login") : undefined }) })
            })
            if (q === "") return all.sort((a, b) => a.text.localeCompare(b.text)).map(x => x.item)   // a fixed order: toggling doesn't move rows
        } else if (level === "launcherprefs") {
            // The footer's key hints always show; these are the extras
            return [{ kind: "lpref", key: "fuzzy", name: "Fuzzy search", glyph: prefs.fuzzy ? "toggle-right" : "toggle-left",
                      sub: "Typos and initials also match: firefx, vsc", summary: prefs.fuzzy ? "on" : "off" },
                    { kind: "lpref", key: "shortcuts", name: "Shortcut hints", glyph: prefs.shortcuts ? "toggle-right" : "toggle-left",
                      sub: "An app’s or menu’s keys on its row (⌘⇧P)", summary: prefs.shortcuts ? "on" : "off" }]
        } else if (level === "plugins") {
            // Enter runs the installer in a terminal (they ask things: sudo, tokens, logins); an installed one can be run again
            if (pluginList === null) return hint("Loading…")
            all = pluginList.map(p => ({ item: { kind: "action", name: p.name, glyph: p.icon, sub: p.desc, installed: p.installed,
                                                 summary: p.installed ? "installed" : undefined,
                                                 cmd: term('"$HOME/.local/bin/nightdrive" plugins install "$1"', p.name) },
                                         text: p.name, extra: p.desc }))
        } else if (level === "remove") {
            if (!removeLoaded) return [{ kind: "hint", name: "Loading packages…" }]
            all = removeList.map(p => ({ item: p, text: p.name, extra: p.summary }))
        } else {
            all = (statics[level] || []).map(r => ({ item: r, text: r.kind === "header" ? "" : r.name }))   // a search drops the headers
        }
        if (q === "") return level === "keys" ? grouped(all.map(x => x.item)) : all.map(x => x.item)
        const scored = []
        // Several words: each may hit the name or the search words ("olohuone kattovalo" → the room is in extra, the name in text)
        const fq = fold(q)
        const words = fq.split(/\s+/).filter(w => w !== "")
        const fuzzyOk = prefs.fuzzy && level !== "emoji"   // thousands of short names: letters in order would hit too many
        all.forEach((x, i) => {
            let s = score(x.text, fq)
            const extra = x.extra ? fold(x.extra) : ""
            if (s < 0 && extra.includes(fq)) s = 3
            if (s < 0 && words.length > 1) {
                const hay = fold(x.text) + " " + extra
                if (words.every(w => hay.includes(w))) s = 4
                // 5: the same with typos and shortcuts, each word fuzzy ("olohuone kattovlo")
                else if (fuzzyOk && words.every(w => hay.includes(w) || fuzzy(hay, w))) s = 5
            }
            if (s < 0 && fuzzyOk && words.length === 1 && fuzzy(fold(x.text), fq)) s = 5
            if (s >= 0) scored.push({ x: x, s: s, i: i })
        })
        scored.sort((a, b) => (a.s - b.s) || (level === "apps" ? a.x.text.localeCompare(b.x.text) : level === "emoji" ? (a.x.text.length - b.x.text.length) || (a.i - b.i) : a.i - b.i))
        const res = scored.map(o => o.x.item)
        return level === "keys" ? grouped(res) : res
    }
    readonly property var results: items()

    // The row each level had selected when a sublevel was opened (by name: a search may have been on), so Esc returns to it
    property var lastSel: ({})
    function go(target) {
        const cur = results[list.currentIndex]
        if (cur && cur.name && target !== level && (parents[target] || "root") === level)   // going down one level
            lastSel[level] = { kind: cur.kind, name: cur.name }
        level = target; input.text = ""; query = ""; armed = ""; playerFocused = false; detail = null; detailInfo = null
        hiddenProc.running = true
        if (target === "keys") keysProc.running = true     // re-read SHORTCUTS.md: changes show up immediately
        list.currentIndex = firstSelectable()
        installResults = []
        if (target === "remove") removeProc.running = true
        if (target === "plugins") pluginsProc.running = true
        if (target === "emoji" && !emojiLoaded) emojiProc.running = true
        if (target === "clipboard") { clipLoaded = false; clipProc.running = true }
        if (target === "background") wallProc.running = true
        if (target === "topbar" || target === "baropacity" || target === "baricons" || target === "barhl") barProc.running = true
        if (target === "theme" || target === "themecolor") themeProc.running = true
        if (target === "display") { displayProc.running = true; brightProc.running = true; nightProc.running = true; sys.entered("display") }
        if (target === "battery") { battProc.running = true; battDetailProc.running = true }
        if (target === "screensaver" || target === "saverafter" || target === "screenoff" || target === "saverstyle") idleProc.running = true
        if (target === "sounds" || target === "soundregular" || target === "soundurgent") soundsProc.running = true
        if (extOf(target)) extOf(target).entered(target)
        if (target === "passwords") { pwState = pwItems.length ? "ready" : "loading"; pwProc.running = true }
    }
    // Background apps (⌘W hides them to special:bg, ⌘Q quits): app name -> window class regex, from hypr/background-apps(.local),
    // the same list close-or-hide uses. An open app (also a hidden one) gets a green dot at the right end of its row.
    property var bgApps: ({})
    Sh {
        id: bgAppsProc   // re-read on every open, so an app added to the list works without restarting the shell
        script: 'cd "$HOME/.config/hypr" && cat background-apps background-apps.local 2>/dev/null'
        running: true
        onResult: text => {
            const m = {}
            for (const l of text.split("\n")) {
                const i = l.indexOf(" = ")
                if (i > 0 && !l.startsWith("#")) m[l.slice(0, i).trim()] = l.slice(i + 3).trim()
            }
            win.bgApps = m
        }
    }
    property var runningClasses: []    // classes of all open windows (lowercase)
    // Whether an app has a window open (on any workspace, also in the background): background apps by their class list (bgApps),
    // others by the .desktop file's StartupWMClass or id
    function appRunning(item) {
        if (item.kind !== "app" || !item.entry) return false
        const re = bgApps[item.name]
        if (re !== undefined) return runningClasses.some(c => new RegExp(re, "i").test(c))
        const e = item.entry
        const wm = (e.startupClass || "").toLowerCase()
        const id = (e.id || "").replace(/\.desktop$/, "").toLowerCase()
        return runningClasses.some(c => (wm !== "" && c === wm) || (id !== "" && c === id))
    }
    Sh {
        id: bgProc
        script: 'hyprctl -j clients | jq -r \'.[].class\''
        onResult: text => { win.runningClasses = text.split("\n").filter(l => l !== "" && !l.startsWith("__")).map(l => l.toLowerCase()) }
    }
    Timer { interval: 1500; repeat: true; running: win.open; onTriggered: bgProc.running = true }
    // Settings rows applied live: kind → [script, verb, property that holds the current value ("" = themecolor, which marks themeList)]
    readonly property var live: ({
        baropacity: ["bar-style", "opacity", "barOpacity"],
        idlesaver: ["idle", "saver", "idleSaver"],
        idleoff: ["idle", "off", "idleOff"],
        idlestyle: ["idle", "style", "idleStyle"],
        baricons: ["bar-style", "icons", "barIcons"],
        bariconop: ["bar-style", "icon-opacity", "barIconOp"],
        barhl: ["bar-style", "highlight", "barHl"],
        themecolor: ["theme", "color", ""]
    })
    // ⌃Enter on an app: the choice goes to ~/.local/state/nightdrive/apps.json ({"shown": [ids], "hidden": [ids]}), then sync-apps
    // updates the overrides (fuzzel/sync-apps) and the list follows
    function appId(item) {
        const id = item.entry ? item.entry.id : item.path.split("/").pop()
        return id.endsWith(".desktop") ? id : id + ".desktop"
    }
    property var pinPending: ({})           // id -> the app's row in its new state, until both sources have caught up
    function togglePin(item) {
        keepSelection()
        const n = Object.assign({}, pinPending)
        n[appId(item)] = Object.assign({}, item, { shown: !item.shown })
        pinPending = n
        pinProc.environment = { "ID": appId(item), "TO": item.shown ? "hidden" : "shown" }
        pinProc.running = true
    }
    // A pending app is done once its new place is in the sources (and its old place is gone); the timer is a fallback
    function prunePins() {
        let changed = false
        const n = Object.assign({}, pinPending)
        for (const id in n) {
            const inApps = apps.some(e => !e.noDisplay && appId({ entry: e }) === id)
            const inHidden = syncHidden.some(h => appId({ path: h.path }) === id)
            if (n[id].shown ? inApps && !inHidden : inHidden && !inApps) { delete n[id]; changed = true }
        }
        if (changed) pinPending = n
    }
    onAppsChanged: prunePins()
    onSyncHiddenChanged: prunePins()
    Timer { id: pinSettle; interval: 5000; onTriggered: win.pinPending = ({}) }
    Sh {
        id: pinProc
        // The id moves to one list and out of the other; other keys in the file are kept (room for more settings later)
        script: 'f="$HOME/.local/state/nightdrive/apps.json"; mkdir -p "${f%/*}"; [ -s "$f" ] || echo "{}" > "$f"
jq --arg id "$ID" --arg to "$TO" \'.shown = ((.shown // []) - [$id]) | .hidden = ((.hidden // []) - [$id]) | .[$to] += [$id]\' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
"$HOME/.config/fuzzel/sync-apps" >/dev/null'
        onResult: { hiddenProc.running = true; pinSettle.restart() }   // (prunePins runs when the lists change)
    }

    // Login apps (Settings › Startup, ⌥Enter on an app): hypr/scripts/autostart keeps the list and starts them at login
    property var autostartIds: []
    Sh {
        id: autostartProc
        command: [win.scripts + "/autostart", "list"]
        onResult: text => { win.autostartIds = text.split("\n").filter(l => l !== "") }
    }
    function toggleAutostart(item) {
        keepSelection()
        const id = appId(item)
        autostartIds = autostartIds.indexOf(id) >= 0 ? autostartIds.filter(x => x !== id) : autostartIds.concat([id])   // shown at once
        Quickshell.execDetached([scripts + "/autostart", "toggle", id])
    }

    function activate(item) {
        if (!item) return
        if (item.kind === "nav") go(item.target)
        else if (item.kind === "app" && level === "startup") toggleAutostart(item)
        else if (item.kind === "app") {
            win.open = false
            // Background app: bring the hidden window back (no second instance)
            if (item.entry && bgApps[item.name] !== undefined)
                Quickshell.execDetached([scripts + "/launch-or-focus", bgApps[item.name], "gtk-launch", item.entry.id + ".desktop"])
            else if (item.entry) item.entry.execute(); else Quickshell.execDetached(["gio", "launch", item.path])
        }
        else if (item.kind === "clip") clipPick(item, true)
        else if (item.kind === "album") { win.open = false; Quickshell.execDetached([scripts + "/deck-ctl", "play-album", item.uri]) }
        else if (item.kind === "spotifyartist") {
            artist = { id: item.id, name: item.name, albums: null }
            artistProc.environment = { "ID": item.id }
            artistProc.running = true
            go("artist")
        }
        else if (item.kind === "decksearch") { win.open = false; Quickshell.execDetached([scripts + "/deck-ctl", "search", item.value]) }
        else if (item.kind === "emoji") emojiPick(item, true)
        else if (item.kind === "stat" && item.copy !== undefined) sys.copyText(item.copy)   // Public IP, Local IP, Router: as ⌘C
        else if (item.kind === "brightness" || item.kind === "stat") shake.restart()   // brightness: ←/→ or the slider; stat: information only
        else if (item.kind === "lpref") { keepSelection(); setPref(item.key, !prefs[item.key]) }
        else if (item.kind === "nightlight") {
            keepSelection()
            night = night === "on" ? "off" : "on"
            Quickshell.execDetached([scripts + "/nightlight", night])
        }
        else if (item.kind === "scale") {     // stays open like the theme rows; Hyprland reloads with the new scale
            keepSelection()
            displays = displays.map(d => d.name === item.output ? Object.assign({}, d, { scale: item.value }) : d)
            Quickshell.execDetached([scripts + "/display", "scale", item.output, String(item.value)])
        }
        else if (item.kind === "baritem") { keepSelection(); TopBar.setHidden(item.value, TopBar.hidden.indexOf(item.value) < 0) }
        else if (item.kind === "sound") {     // stays open: each sound plays as it's chosen, so they can be compared
            keepSelection()
            win[item.which === "regular" ? "soundRegular" : "soundUrgent"] = item.value
            Quickshell.execDetached(["bash", "-c", '"$1" "$2" "$3" && "$1" play "$2"', "_", scripts + "/sounds", item.which, item.value])
        }
        else if (live[item.kind]) {           // stays open: values can be tried one after another (theme colors recolor the launcher immediately)
            const [script, verb, prop] = live[item.kind]
            keepSelection()
            if (prop) win[prop] = item.value
            else themeList = themeList.map(t => Object.assign({}, t, { current: t.value === item.value }))
            Quickshell.execDetached([scripts + "/" + script, verb, String(item.value)])
        }
        else if (item.kind === "walladd") {   // launcher closes while the picker is open; the script reopens Background
            win.open = false
            Quickshell.execDetached([scripts + "/wallpaper", "add"])
        }
        else if (item.kind === "wall") {      // launcher stays open: wallpapers can be tried one after another, Esc closes
            wallCurrent = item.path
            Quickshell.execDetached([scripts + "/wallpaper", "set", item.path])
        }
        else if (item.kind === "wname") { webName = item.value; go("webaddr") }
        else if (item.kind === "wadd") {
            win.open = false
            Quickshell.execDetached(["bash", "-c",
                'out=$("$HOME/.config/hypr/scripts/webapp-add" "$1" "$2" 2>&1) && notify-send -a Webapp "Webapp added" "$1" || notify-send -u critical -a Webapp "Adding webapp failed" "$out"',
                "_", webName, item.value])
        }
        else if (sys.activate(item)) {}
        else if (home.activate(item)) {}
        else if (ext && ext.activate(item)) {}
        else if (item.kind === "pw") copyField(item, "password")
        else if (item.kind === "menu") { win.open = false; win.openMenu(item.target) }
        else if (item.src && detail === null) showDetail(item)
        else if (item.kind === "action") {
            if (item.confirm && armed !== item.name) { armed = item.name; disarm.restart(); return }
            armed = ""; win.open = false
            Quickshell.execDetached(item.cmd)
        }
    }
    // Pastes into the active window by sending Shift+Insert (same as ⌘V; kitty etc. treat it as a clipboard paste).
    // The launcher closes first, so the short sleep lets focus return to the previous window.
    readonly property string pasteCmd: 'sleep 0.2; hyprctl dispatch \'hl.dsp.send_shortcut({ mods = "SHIFT", key = "Insert" })\' >/dev/null'
    // Clipboard: copies the selection to the clipboard and (paste) pastes it into the active window
    function clipPick(item, paste) {
        win.open = false
        Quickshell.execDetached(["bash", "-c",
            'cliphist decode "$1" | wl-copy; [ "$2" = 1 ] && { ' + pasteCmd + '; }',
            "_", item.id, paste ? "1" : "0"])
    }
    // Emoji: copies to the clipboard and (paste) pastes into the active window like clipPick; copy-only shows a notification
    function emojiPick(item, paste) {
        win.open = false
        Quickshell.execDetached(["bash", "-c",
            'printf %s "$1" | wl-copy; if [ "$3" = 1 ]; then ' + pasteCmd + '; else notify-send -a Emoji -t 1500 "Copied $1" "$2"; fi',
            "_", item.emoji, item.name, paste ? "1" : "0"])
    }
    // Passwords: field → [message when missing, message when copied, secret (1 = sensitive + cleared after 45 s), op item get options...]
    readonly property var pwFields: ({
        password: ["No password field in this item", "Password copied", "1", "--fields", "label=password", "--reveal"],
        otp: ["No one-time password in this item", "One-time code copied", "1", "--otp"],
        username: ["No username in this item", "Username copied", "0", "--fields", "label=username"]
    })
    // Copies the field to the clipboard. Secrets are marked as sensitive (cliphist doesn't store them in history) and cleared after 45 s.
    function copyField(item, field) {
        if (!item || item.kind !== "pw") return
        win.open = false
        const script = 'id=$1 missing=$2 copied=$3 secret=$4; shift 4; ' +
            'v=$(op item get "$id" "$@" 2>/dev/null); [ -z "$v" ] && { notify-send -u critical "1Password" "$missing"; exit; }; ' +
            'if [ "$secret" = 1 ]; then printf %s "$v" | wl-copy --sensitive; notify-send -t 4000 "1Password" "$copied. Clears in 45 s"; sleep 45; ' +
            '[ "$(wl-paste -n 2>/dev/null)" = "$v" ] && wl-copy --clear; ' +
            'else printf %s "$v" | wl-copy; notify-send -t 3000 "1Password" "$copied"; fi'
        Quickshell.execDetached(["bash", "-c", script, "_", item.id].concat(pwFields[field] || pwFields.username))
    }
    // Shift+Enter on an extension row; rows with armKey need a second press to confirm
    function extShift(item) {
        if (item.armKey !== undefined && armed !== item.armKey) { armed = item.armKey; disarm.restart(); return }
        armed = ""
        const target = extOf(level) || ext   // not "armed = ''\n(…)": that would parse as a call of ""
        target.shiftActivate(item)
    }
    // ⌘⌫ / ⌥⌫ in the query: a selection goes first, otherwise to the line start (word = only the word before the cursor)
    function deleteBack(word) {
        if (input.selectedText !== "") { input.remove(input.selectionStart, input.selectionEnd); return }
        const end = input.cursorPosition
        let start = 0
        if (word) {
            start = end
            while (start > 0 && /\s/.test(input.text[start - 1])) start--
            while (start > 0 && !/\s/.test(input.text[start - 1])) start--
        }
        if (start < end) input.remove(start, end)
    }
    // ⌘⌫ in Background (bindings.lua → IPC deleteSelected): a second press moves your own image to the trash.
    // Only your own images (~/Pictures/Wallpapers, `own` from hypr/scripts/wallpaper list); bundled ones can't be deleted.
    function deleteWall() {
        const item = results[list.currentIndex]
        if (!item || item.kind !== "wall" || !item.own) { shake.restart(); return }
        const key = "del:" + item.path
        if (armed !== key) { armed = key; disarm.restart(); return }
        armed = ""
        if (wallCurrent === item.path) wallCurrent = ""
        wallList = wallList.filter(w => w.path !== item.path)
        if (list.currentIndex >= results.length) list.currentIndex = results.length - 1
        Quickshell.execDetached([scripts + "/wallpaper", "remove", item.path])
        wallReload.restart()
    }
    Timer { id: wallReload; interval: 600; onTriggered: wallProc.running = true }   // current wallpaper (the default, if the deleted one was in use)

    // The selection changes only when the mouse actually moves. Merely "mouse is over a row" isn't enough,
    // because a stationary cursor left under the launcher (or a scrolling list) would trigger it.
    function hover(area, mouse, index) {
        const p = area.mapToItem(null, mouse.x, mouse.y)
        if (lastMouse === null) { lastMouse = Qt.point(p.x, p.y); return }   // first event = cursor position
        // Threshold: a sub-pixel jitter from scaling (e.g. 520 → 519.9) isn't movement
        if (Math.abs(p.x - lastMouse.x) + Math.abs(p.y - lastMouse.y) < 3) return
        lastMouse = Qt.point(p.x, p.y)
        playerFocused = false
        list.currentIndex = index
    }
    // The current value is part of the rows (✓, "current"), so changing it rebuilds the list and the selection would jump to the top:
    // restore the selection to the same row after the update
    // Rebuilding the rows resets both the selection and the scroll position: put both back (a scrolled list jumped to the top)
    function keepSelection() {
        const i = list.currentIndex, y = list.contentY
        // The scroll position only after the list has settled on the new rows (in the same call it was reset again)
        Qt.callLater(() => { list.currentIndex = i; Qt.callLater(() => { list.contentY = Math.min(y, Math.max(0, list.contentHeight - list.height)) }) })
    }
    // Selects the first row matching pred (e.g. a setting's current value), if any
    function selectWhere(pred) { const i = results.findIndex(pred); if (i >= 0) list.currentIndex = i }
    function back() {
        if (detail !== null) { detail = null; detailInfo = null; return }
        if (level === "root") { win.open = false; return }
        go(parents[level] || "root")
        const sel = lastSel[level]
        const i = sel ? results.findIndex(r => r.kind === sel.kind && r.name === sel.name) : -1
        if (i >= 0) list.currentIndex = i
    }

    // Closing leaves the details right away (after the Behavior above has seen open = false), so the next open starts narrow
    onOpenChanged: if (!open) Qt.callLater(() => { if (!win.open) { win.detail = null; win.detailInfo = null } })
    else { lastMouse = null; spotify = null; lastSel = ({}); if (ext) ext.opened(); home.opened(); go("root"); deckProc.running = true; musicProc.running = true; bgProc.running = true; bgAppsProc.running = true; autostartProc.running = true; updatesProc.running = true; brightProc.running = true; nightProc.running = true; sys.entered("display"); sys.soundRefresh(); input.forceActiveFocus() }
    Component.onCompleted: keysProc.running = true

    Timer { id: disarm; interval: 4000; onTriggered: win.armed = "" }

    // Player row: Deck's state is read while the launcher is open
    // Keys while the player row is selected. Returns true if the key was handled.
    function handlePlayerKey(event) {
        const k = event.key
        const ctrl = event.modifiers & Qt.ControlModifier
        if (k === Qt.Key_Down || (ctrl && (k === Qt.Key_N || k === Qt.Key_J))) { playerFocused = false; return true }
        if (k === Qt.Key_Up) return true
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) { deckPlayPress(); return true }
        if (k === Qt.Key_Right) { if (deckInfo !== null) deckCtl("next"); return true }
        if (k === Qt.Key_Left) { if (deckInfo !== null) deckCtl("previous"); return true }
        if (ctrl && k === Qt.Key_L) { if (deckInfo !== null) deckCtl("like"); return true }
        if (k === Qt.Key_Escape || k === Qt.Key_Backspace) return false
        if (event.text !== "" && !ctrl) playerFocused = false            // typing returns to the search
        return false
    }
    function launchDeck() {
        win.open = false
        Quickshell.execDetached([scripts + "/deck-open"])
    }
    // Play: something playing → play/pause; nothing playing → start / bring up Deck
    function deckPlayPress() { if (deckInfo === null) launchDeck(); else deckCtl("toggle") }
    function deckCtl(cmd) {
        if (cmd === "toggle") deckOverride = Object.assign({}, deckOverride, { playing: !deckPlaying })
        if (cmd === "like" && deckLiked !== null && deckLiked !== undefined) deckOverride = Object.assign({}, deckOverride, { liked: !deckLiked })
        Quickshell.execDetached([deckBin, "ctl", cmd])
        deckSettle.restart()
    }
    Timer { id: deckSettle; interval: 1000; onTriggered: { win.deckOverride = ({}); deckProc.running = true } }
    Timer { interval: 1500; repeat: true; running: win.open; onTriggered: deckProc.running = true }
    Sh {
        id: deckProc
        script: 'f="$XDG_RUNTIME_DIR/deck/state.json"; [ -s "$f" ] || exit 3; pid=$(jq -r .pid "$f"); [ -d "/proc/$pid" ] || exit 4; cat "$f"'
        onResult: text => {
            if (deckProc.exitCode !== 0) { win.deckAlive = false; win.deckInfo = null; return }
            try { win.deckInfo = JSON.parse(text).info; win.deckAlive = true } catch (e) { win.deckAlive = false; win.deckInfo = null }
        }
    }

    // Install › Software: search while typing (300 ms delay), hypr/scripts/pkg-search: { apps, tools }
    function sanitized() { return query.trim().toLowerCase().replace(/[^a-z0-9._+\-]/g, "") }
    function runSearch() {
        const q = sanitized()
        installQ = q
        if (q.length < 2) { installResults = []; return }
        if (searchProc.running) return                 // the running one notices the query went stale and starts again
        searchProc.command = [scripts + "/pkg-search", q]
        searchProc.forQ = q
        searchProc.running = true
    }
    function installCmd(src, id) {
        return src === "flatpak" ? term('flatpak install --user flathub "$1"', id) : term('sudo dnf install "$1"', id)
    }
    // dnf repoquery output ("name|summary" per line) → [{ name, summary }]
    function parsePackages(text) {
        const out = []
        for (const line of text.split("\n")) {
            const i = line.indexOf("|")
            if (i >= 0) out.push({ name: line.slice(0, i), summary: line.slice(i + 1) })
        }
        return out
    }
    onQueryChanged: {
        if (level === "software") { armed = ""; searchDelay.restart() }
        if (level === "musicsearch" && query.trim() !== "") spotifyDelay.restart()
    }
    Timer { id: searchDelay; interval: 300; onTriggered: win.runSearch() }
    Sh {
        id: searchProc
        property string forQ: ""
        onResult: text => {
            if (win.level !== "software") return          // left the level while searching
            if (win.sanitized() !== forQ) { win.runSearch(); return }
            let r
            try { r = JSON.parse(text) } catch (e) { win.installResults = []; return }
            const row = (p, glyph) => ({ kind: "action", name: p.name, sub: p.summary, iconFile: p.icon || undefined,
                                         glyph: p.icon ? undefined : glyph, src: p.src, id: p.id, alt: p.alt,
                                         summary: p.installed ? "installed" : undefined, cmd: win.installCmd(p.src, p.id) })
            // The headers only when both are there: one kind alone needs no title
            const both = r.apps.length > 0 && r.tools.length > 0
            const out = []
            if (both) out.push({ kind: "header", name: "Apps" })
            for (const p of r.apps) out.push(row(p, "package-plus"))
            if (both) out.push({ kind: "header", name: "Command-line tools" })
            for (const p of r.tools) out.push(row(p, "terminal"))
            win.installResults = out
            list.currentIndex = win.firstSelectable()
        }
    }
    // Install / Remove: a package's details (hypr/scripts/pkg-info). The results stay as they were behind them.
    function showDetail(item) {
        detail = item; detailInfo = null; armed = ""
        detailView.contentY = 0
        if (!detailProc.running) runDetail()          // otherwise the running one notices it's stale and starts again
    }
    function runDetail() {
        detailProc.forId = detail.src + ":" + detail.id
        detailProc.command = [scripts + "/pkg-info", detail.src, detail.id]
        detailProc.running = true
    }
    // Enter in the details: installs / removes in a terminal (an installed package can't be installed again)
    function detailConfirm() {
        if (!detail.remove && detailInfo && detailInfo.installed) { shake.restart(); return }
        win.open = false
        Quickshell.execDetached(detail.cmd)
    }
    // Tab in the details: the same app from the other source (Fedora ↔ Flathub)
    function detailSwitch() {
        const a = detail.alt
        if (!a) { shake.restart(); return }
        showDetail(Object.assign({}, detail, { src: a.src, id: a.id, alt: { src: detail.src, id: detail.id }, cmd: installCmd(a.src, a.id) }))
    }
    function detailScroll(dy) {
        detailView.contentY = Math.max(0, Math.min(detailView.contentHeight - detailView.height, detailView.contentY + dy))
    }
    Sh {
        id: detailProc
        property string forId: ""
        onResult: text => {
            if (win.detail === null) return
            if (win.detail.src + ":" + win.detail.id !== forId) { win.runDetail(); return }
            try { win.detailInfo = JSON.parse(text) }
            catch (e) { win.detailInfo = { name: win.detail.name, summary: win.detail.summary, installed: false, icon: "", screenshot: "", paragraphs: [], fields: [["Details", "not available"]] } }
        }
    }
    SystemLevels { id: sys; launcher: win }
    HomeLevels { id: home; launcher: win }
    Loader {
        id: extLoader
        source: win.extSource
        onLoaded: item.launcher = win
    }
    // Music: Deck's shelf (sorted by artist and year, like in Deck) and the Curated list; read on every open
    // An album row: the album's name with ARTIST below it (small, theme colour), the year on the right; an artist's own
    // album list leaves the artist out
    function albumItem(a, withArtist = true) {
        return { kind: "album", name: a.name, artist: withArtist && a.artist ? a.artist : "", summary: a.year ? String(a.year) : "", glyph: "disc-3", uri: a.uri }
    }
    function esc(t) { return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
    Sh {
        id: musicProc
        script: 'd="$HOME/.config/deck"; s=$(cat "$d/shelf.json" 2>/dev/null || echo "[]"); c=$(cat "$d/curated.json" 2>/dev/null || echo "{}")
jq -cn --argjson s "$s" --argjson c "$c" \'[($s | sort_by((.artist | ascii_downcase), .year) | .[] | {uri, name, artist, year, list: "shelf"}),
  ($c.albums // [] | .[] | {uri, name, artist, year, list: "curated"})]\''
        onResult: text => { try { win.musicAlbums = JSON.parse(text) } catch (e) { win.musicAlbums = [] } }
    }
    // Music › Search: Spotify through Deck's own client (needs client_id in Deck's config.toml); one request after typing pauses
    Timer { id: spotifyDelay; interval: 450; onTriggered: win.searchSpotify() }
    function searchSpotify() {
        const q = query.trim()
        if (q.length < 2 || spotifyProc.running) return
        spotifyProc.environment = { "Q": q }
        spotifyProc.running = true
    }
    Sh {
        id: spotifyProc
        script: '"$HOME/.local/bin/deck" search --json "$Q"'
        onResult: text => {
            const q = spotifyProc.environment.Q
            try {
                if (spotifyProc.exitCode !== 0) throw new Error(text.trim().split("\n").pop() || "Search failed")
                const r = JSON.parse(text)
                win.spotify = { query: q, artists: r.artists || [], albums: r.albums || [], error: "" }
            } catch (e) { win.spotify = { query: q, artists: [], albums: [], error: String(e.message || e).replace(/^deck: /, "") } }
            if (win.level === "musicsearch" && win.query.trim() !== "" && win.query.trim() !== q) win.searchSpotify()   // typed on meanwhile
        }
    }
    Sh {
        id: artistProc
        script: '"$HOME/.local/bin/deck" artist-albums --json "$ID"'
        onResult: text => {
            let albums = []
            try { albums = JSON.parse(text) } catch (e) {}
            if (win.artist.id === artistProc.environment.ID) win.artist = Object.assign({}, win.artist, { albums: albums })
        }
    }
    // Settings › Background: wallpapers and their previews (the script creates missing previews the first time)
    Sh {
        id: wallProc
        script: 's="$HOME/.config/hypr/scripts/wallpaper"; "$s" current; "$s" list'
        onResult: text => {
            const lines = text.split("\n").filter(l => l !== "")
            win.wallCurrent = lines.length ? lines[0] : ""
            win.wallList = lines.slice(1).map(l => l.split("\t")).filter(f => f.length >= 4)
                .map(f => ({ path: f[0], thumb: f[1], name: f[2], group: f[3], own: f[4] === "1" }))
            const first = !win.wallLoaded
            win.wallLoaded = true
            // On open, select the current wallpaper
            if (first || win.query === "") win.selectWhere(r => r.path === win.wallCurrent)
        }
    }
    // Settings › Theme › Color: themes and the current one; select the current one
    Sh {
        id: themeProc
        command: [win.scripts + "/theme", "list"]
        onResult: text => {
            win.themeList = text.split("\n").map(l => l.split("\t")).filter(f => f.length >= 3)
                .map(f => ({ value: f[0], name: f[1], swatch: f[2], current: f[3] === "current" }))
            if (win.level === "themecolor" && win.query === "") win.selectWhere(r => r.value === (win.themeList.find(t => t.current) || {}).value)
        }
    }
    Sh {
        id: updatesProc
        script: 'cat "$HOME/.cache/nightdrive/updates" 2>/dev/null'
        onResult: text => { win.updates = parseInt(text, 10) || 0 }
    }
    // Settings › Display: outputs and their even scales; select the current one
    Sh {
        id: displayProc
        script: '"$HOME/.config/hypr/scripts/display" list'
        onResult: text => {
            const first = win.displays === null
            win.displays = text.split("\n").map(l => l.split("\t")).filter(f => f.length >= 4).map(f => ({
                name: f[0], desc: f[1], scale: parseFloat(f[2]),
                opts: f.slice(3).map(o => { const [v, size] = o.split(":"); return { value: parseFloat(v), size: size.replace("×", " × ") } }) }))
            if (first && win.level === "display" && win.query === "") list.currentIndex = win.firstSelectable()   // was the Loading… hint
        }
    }
    // Settings › Display › Brightness: read on entering and every 2 s while there (the brightness keys also work then),
    // not while the slider is held or a value is waiting to be applied
    Sh {
        id: brightProc
        // -c backlight: without a backlight brightnessctl would pick the first LED (a keyboard's Compose light)
        command: ["brightnessctl", "-m", "-c", "backlight"]
        onResult: text => {
            if (win.pendingBright >= 0) return
            const first = win.bright < 0
            const f = text.trim().split(",")
            const v = f.length >= 4 ? parseInt(f[3]) / 100 : -1
            if (v !== win.bright && !first) win.keepSelection()   // changed elsewhere (the brightness keys)
            win.bright = v
            // The rows above the scales appear only now: select the first one (the brightness row)
            if (first && win.bright >= 0 && win.level === "display" && win.query === "") list.currentIndex = win.firstSelectable()
        }
    }
    Timer { interval: 2000; repeat: true; running: win.open && win.level === "display"; onTriggered: brightProc.running = true }
    Sh {
        id: nightProc
        script: '"$HOME/.config/hypr/scripts/nightlight" status'
        onResult: text => { win.night = text.trim() }
    }
    // Settings › Battery: the machine's own battery, found like in topbar/scripts/status (MacBook: macsmc-battery);
    // read on entering and every 5 s while there
    Sh {
        id: battProc
        script: 'for d in /sys/class/power_supply/*; do [ "$(cat "$d/type")" = Battery ] && [ "$(cat "$d/scope" 2>/dev/null)" != Device ] &&
                 { upower -i "/org/freedesktop/UPower/devices/battery_$(basename "$d" | tr - _)"; break; }; done'
        onResult: text => {
            const g = re => { const r = text.match(re); return r ? r[1].trim() : "" }
            const fmt = (v, unit) => {
                const min = Math.round(parseFloat(v.replace(",", ".")) * (/hour/.test(unit) ? 60 : /second/.test(unit) ? 1 / 60 : 1))
                return Math.floor(min / 60) > 0 ? Math.floor(min / 60) + " h " + (min % 60) + " min" : min + " min"
            }
            const st = g(/state:\s*(\S+)/)
            const tte = text.match(/time to empty:\s*([\d.,]+)\s*(\w+)/)
            const ttf = text.match(/time to full:\s*([\d.,]+)\s*(\w+)/)
            if (st === "") { win.batt = null; return }
            win.keepSelection()
            win.batt = { percent: parseInt(g(/percentage:\s*(\d+)/)) || 0, state: st,
                         timeText: st === "discharging" && tte ? fmt(tte[1], tte[2]) : st === "charging" && ttf ? fmt(ttf[1], ttf[2]) : "" }
        }
    }
    Sh {
        id: battDetailProc
        command: ["bash", "-c", "~/.config/topbar/scripts/sysinfo battery"]
        onResult: text => { try { win.battDetail = JSON.parse(text) } catch (e) { win.battDetail = null } }
    }
    Timer { interval: 5000; repeat: true; running: win.open && win.level === "battery"; onTriggered: { battProc.running = true; battDetailProc.running = true } }
    Timer {
        id: brightApply; interval: 60
        onTriggered: {
            if (win.pendingBright < 0) return
            Quickshell.execDetached(["brightnessctl", "-c", "backlight", "-n2", "set", Math.round(win.pendingBright * 100) + "%"])
            win.pendingBright = -1
        }
    }
    // keepSelection: the new percentage rebuilds the rows, which would move the selection to the top
    function setBright(v) { keepSelection(); bright = v; pendingBright = v; if (!brightApply.running) brightApply.start() }
    // ←/→: to the next even step, like the brightness keys
    function stepBright(dir) {
        const p = Math.round(bright * 100)
        const n = dir > 0 ? (Math.floor(p / brightStep) + 1) * brightStep : (p % brightStep === 0 ? p - brightStep : Math.floor(p / brightStep) * brightStep)
        setBright(Math.max(0, Math.min(100, n)) / 100)
    }
    // Settings › Screensaver: current idle times; select the current one
    Sh {
        id: idleProc
        script: 's="$HOME/.config/hypr/scripts/idle"; "$s" saver; "$s" off; "$s" style'
        onResult: text => {
            const f = text.trim().split("\n")
            win.idleSaver = parseInt(f[0], 10)
            win.idleOff = parseInt(f[1], 10)
            win.idleStyle = f[2] || ""
            if (win.level === "saverstyle" && win.query === "") win.selectWhere(r => r.value === win.idleStyle)
            if ((win.level === "saverafter" || win.level === "screenoff") && win.query === "")
                win.selectWhere(r => r.value === (win.level === "saverafter" ? win.idleSaver : win.idleOff))
        }
    }
    // ⇧Enter on a sound: plays it without choosing it ("None" has nothing to play)
    function listenSound(item) {
        if (item.value === "none") { shake.restart(); return }
        Quickshell.execDetached([scripts + "/sounds", "play", item.which, item.value])
    }
    // Settings › Notifications: the current sounds; select the current one
    Sh {
        id: soundsProc
        script: 's="$HOME/.config/hypr/scripts/sounds"; "$s" regular; "$s" urgent'
        onResult: text => {
            const f = text.trim().split("\n")
            win.soundRegular = f[0] || ""
            win.soundUrgent = f[1] || ""
            if ((win.level === "soundregular" || win.level === "soundurgent") && win.query === "")
                win.selectWhere(r => r.value === (win.level === "soundregular" ? win.soundRegular : win.soundUrgent))
        }
    }
    // Settings › Top bar opacity / icons: current values; select the current one
    Sh {
        id: barProc
        script: 's="$HOME/.config/hypr/scripts/bar-style"; "$s" opacity; "$s" icons; "$s" icon-opacity; "$s" highlight'
        onResult: text => {
            const f = text.trim().split("\n")
            win.barOpacity = parseInt(f[0], 10)
            win.barIcons = f[1] || ""
            win.barIconOp = parseInt(f[2], 10)
            win.barHl = f[3] || ""
            if (win.level === "baropacity" && win.query === "") win.selectWhere(r => r.value === win.barOpacity)
            if (win.level === "barhl" && win.query === "") win.selectWhere(r => r.value === win.barHl)
            if (win.level === "baricons" && win.query === "") win.selectWhere(r => r.value === win.barIcons)
        }
    }
    // Clipboard: cliphist list ("<id>\t<preview>", newest first). Sensitive entries (passwords) don't end up in history.
    Sh {
        id: clipProc
        command: ["bash", "-c", "cliphist list 2>/dev/null | head -300"]
        onResult: text => {
            const out = []
            for (const line of text.split("\n")) {
                const i = line.indexOf("\t")
                if (i < 0) continue
                const raw = line.slice(i + 1)
                const binary = /^\[\[ binary data/.test(raw)
                out.push({ kind: "clip", id: line.slice(0, i), name: raw.replace(/\s+/g, " ").trim().slice(0, 200) || "(blank)",
                           glyph: binary ? "image" : "clipboard" })
            }
            win.clipItems = out
            win.clipLoaded = true
        }
    }
    // Passwords: op item list (requires the 1Password app and CLI integration: Settings › Developer › Integrate with 1Password CLI)
    Sh {
        id: pwProc
        script: 'op item list --format json 2>&1'
        onResult: text => {
            let arr = null
            try { arr = JSON.parse(text) } catch (e) {}
            if (!Array.isArray(arr) || pwProc.exitCode !== 0) {
                const msg = text.trim().replace(/^\[ERROR\]\s*\d{4}\/\d\d\d\d?\/?\d* ?\d\d:\d\d:\d\d\s*/gm, "").split("\n")[0]
                const connect = /account|sign|integrat|connect|not found|no such/i.test(text)
                win.pwError = connect
                    ? "1Password CLI isn't connected.\nStart 1Password (⌘P) and unlock it, then open\nSettings › Developer › “Integrate with 1Password CLI”."
                    : (msg || "1Password CLI returned nothing")
                win.pwState = "error"
                return
            }
            const glyphs = { LOGIN: "key-round", PASSWORD: "lock-keyhole", SECURE_NOTE: "sticky-note", CREDIT_CARD: "credit-card",
                             IDENTITY: "user-round", API_CREDENTIAL: "terminal", SERVER: "server", WIRELESS_ROUTER: "wifi" }
            win.pwItems = arr.map(it => ({
                kind: "pw", id: it.id, name: it.title || "(untitled)",
                summary: it.additional_information || "",
                urls: (it.urls || []).map(u => u.href || "").join(" "),
                glyph: glyphs[it.category] || "key-round"
            })).sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()))
            win.pwState = "ready"
        }
    }
    // Emoji: data/emoji.tsv ("char<TAB>name<TAB>keywords", generated from CLDR annotations)
    Sh {
        id: emojiProc
        command: ["cat", Quickshell.env("HOME") + "/.config/quickshell/data/emoji.tsv"]
        onResult: text => {
            const out = []
            for (const line of text.split("\n")) {
                const f = line.split("\t")
                if (f.length >= 2) out.push({ ch: f[0], name: f[1], kw: f[2] || "" })
            }
            win.emojiList = out
            win.emojiLoaded = true
        }
    }
    // Install › Plugins: plugins.txt via `nightdrive plugins` (name, icon, description, installer, installed 1/0)
    Sh {
        id: pluginsProc
        command: [Quickshell.env("HOME") + "/.local/bin/nightdrive", "plugins"]
        onResult: text => {
            win.pluginList = text.split("\n").map(l => l.split("\t")).filter(f => f.length >= 5)
                .map(f => ({ name: f[0], icon: f[1], desc: f[2], installed: f[4] === "1" }))
        }
    }
    // Remove: packages the user installed, then the user's Flatpak apps (after a "--flatpak--" line, tab-separated)
    Sh {
        id: removeProc
        script: 'dnf repoquery --userinstalled -q --queryformat "%{name}|%{summary}\\n" 2>/dev/null | sort -u; echo --flatpak--; flatpak list --app --user --columns=application,name,description 2>/dev/null'
        onResult: text => {
            const [dnf, fp] = text.split("--flatpak--\n")
            const apps = (fp || "").split("\n").map(l => l.split("\t")).filter(f => f[1])
            win.removeList = win.parsePackages(dnf).map(p => ({ kind: "action", name: p.name, summary: p.summary, glyph: "package-minus",
                                                                 src: "dnf", id: p.name, remove: true, cmd: win.term('sudo dnf remove "$1"', p.name) }))
                .concat(apps.map(([id, name, desc]) => ({ kind: "action", name: name, summary: (desc || "") + "  ·  Flatpak", glyph: "package-minus",
                                                            src: "flatpak", id: id, remove: true, cmd: win.term('flatpak uninstall --user "$1"', id) })))
            win.removeLoaded = true
        }
    }

    // overrides marked by sync-apps → ids of hidden apps
    Sh {
        id: hiddenProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/hidden-apps.sh"]
        onResult: text => {
            win.syncHidden = text.split("\n").filter(l => l.includes("|")).map(l => {
                const f = l.split("|")
                return { path: f[0], name: f[1], icon: f[2], extra: f[3] || "" }
            })
        }
    }

    // A row's shortcut from SHORTCUTS.md ("" = none): apps and the launcher's own items, by name. Names that differ
    // between the launcher and SHORTCUTS.md: shortcutAliases.
    readonly property var shortcutAliases: ({ "kitty": "terminal", "firefox": "browser", "visual studio code": "vs code",
                                              "clipboard": "clipboard history", "emoji": "emoji picker", "keybindings": "this help" })
    function shortcutFor(it) {
        if (!it || !it.name || (it.kind !== "app" && it.kind !== "nav")) return ""
        if (it.kind === "nav" && parents[it.target] === "settings") return ""   // settings pages: "Notifications" is not the ⌘Esc panel
        const n = it.name.toLowerCase()
        return keyIndex[n] || keyIndex[shortcutAliases[n] || ""] || ""
    }

    // A keybinding's text → [name, second line]: the row has no room for long texts. A note in parentheses at the end goes
    // on the second line ("Emoji picker (Enter pastes…)"), and so does what a long name has after its first ": " or "; "
    // outside parentheses ("Play/pause; starts Deck if…").
    function splitKeyText(text) {
        let name = text, sub = ""
        const p = name.match(/^(.*\S)\s*\(([^()]*)\)$/)
        if (p) { name = p[1]; sub = p[2] }
        if (name.length > 36) {
            let depth = 0
            for (let i = 0; i < name.length - 1; i++) {
                const c = name[i]
                if (c === "(") depth++
                else if (c === ")") depth--
                else if (depth === 0 && (c === ":" || c === ";") && name[i + 1] === " ") {
                    sub = name.slice(i + 2) + (sub ? " (" + sub + ")" : "")
                    name = name.slice(0, i)
                    break
                }
            }
        }
        return [name, sub.charAt(0).toUpperCase() + sub.slice(1)]
    }

    // SHORTCUTS.md → [{ name, sub, keys, section }]
    Sh {
        id: keysProc
        script: 'cd "$HOME/.config/hypr" && cat SHORTCUTS.md SHORTCUTS.local.md 2>/dev/null'
        onResult: text => {
            const out = []
            let section = ""
            for (const line of text.split("\n")) {
                const h = line.match(/^##\s+(.*)$/)
                if (h) { section = h[1]; continue }
                // Keys and description are split at the last run of two or more spaces
                const m = line.match(/^ {2}(\S.*) {2,}(\S.*)$/)
                if (!m || !section) continue
                const t = win.splitKeyText(m[2].trim())
                out.push({ keys: m[1].trim(), name: t[0], sub: t[1], section: section })
            }
            win.keyList = out
            // name → keys, for showing an app's or a launcher item's shortcut on its row: the row's name with and without
            // its parentheses, the names in them ("Music (Deck, Spotify)" → deck) and in its note ("Email (Thunderbird,
            // inbox)" → thunderbird). The first of alternatives ("⌘ ⇧ Enter / ⌘ ⇧ B").
            const idx = {}
            for (const k of out) {
                const keys = k.keys.split(" / ")[0]
                const inParens = (k.name.match(/\(([^()]*)\)/g) || []).map(p => p.slice(1, -1)).join(",")
                const names = [k.name, k.name.replace(/\s*\([^()]*\)/g, "")]
                for (const n of names.concat((inParens + "," + k.sub).split(/,\s*/))) {
                    const key = n.trim().toLowerCase()
                    if (key && idx[key] === undefined) idx[key] = keys
                }
            }
            win.keyIndex = idx
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { win.open = !win.open }
        function close(): void { win.open = false }
        // openLevel apps | keys | root: opens a sublevel directly
        function openLevel(level: string): void { win.open = true; win.go(level) }
        function setQuery(text: string): void { input.text = text }
        // askClaude: ⌘⌥Enter with the launcher open and a non-empty query → sends the text to Claude Code (hypr/scripts/terminal-or-claude). Returns "ok" or "".
        function askClaude(): string {
            const q = win.query.trim()
            if (!win.open || q === "" || (win.level !== "root" && win.level !== "apps")) return ""
            win.open = false
            Quickshell.execDetached([win.scripts + "/terminal-or-claude", q])
            return "ok"
        }
        // pick <index>: selects a row like Enter (automated testing)
        function pick(index: int): void { const r = win.results[index]; if (r) win.activate(r); else shake.restart() }
        // ⌘⌫ (bindings.lua): in Background removes your own wallpaper, elsewhere deletes the query to the cursor's left (like macOS)
        function deleteSelected(): void {
            if (!win.open) return
            if (win.level === "background" && win.wallLoaded) win.deleteWall()
            else win.deleteBack(false)
        }
        // ⌥⌫: deletes the word to the cursor's left (Hyprland's binding takes the key, so the launcher does it here)
        function deleteWord(): void { if (win.open) win.deleteBack(true) }
        function stepUp(): void { win.detail !== null ? win.detailScroll(-win.rowHeight) : win.step(-1) }
        function stepDown(): void { win.detail !== null ? win.detailScroll(win.rowHeight) : win.playerFocused ? (win.playerFocused = false) : win.step(1) }
        function back(): void { win.back() }
    }

    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea { anchors.fill: parent; onClicked: win.open = false }

    Rectangle {
        id: card
        width: win.detail !== null ? win.detailWidth : win.cardWidth
        // Animated only while open: a closed launcher drops back to the normal width at once (onOpenChanged)
        Behavior on width { enabled: win.open; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        height: col.implicitHeight + 36
        x: (parent.width - width) / 2
        y: parent.height * win.topPosition
        radius: 12
        color: Theme.launcherBg
        border.color: Theme.primary
        border.width: 2
        // Enter with no results: the card shakes side to side ("no match")
        transform: Translate { id: shakeShift }
        SequentialAnimation {
            id: shake
            NumberAnimation { target: shakeShift; property: "x"; to: -16; duration: 45; easing.type: Easing.OutQuad }
            NumberAnimation { target: shakeShift; property: "x"; to: 16; duration: 80; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeShift; property: "x"; to: -10; duration: 70; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeShift; property: "x"; to: 6; duration: 60; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeShift; property: "x"; to: 0; duration: 50; easing.type: Easing.OutQuad }
        }
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 18 }
            spacing: 12

            // Deck player row (always visible): play/pause, track, next, like. Not playing → play starts Deck
            Rectangle {
                width: parent.width
                height: 40
                radius: 10
                color: win.playerFocused ? Theme.sel : "transparent"

                Text {
                    id: playBtn
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: Icons.g(win.deckPlaying ? "pause" : "play")
                    color: (playArea.containsMouse || win.playerFocused) ? Theme.accent : (win.deckInfo === null ? Theme.dim : Theme.text)
                    font { family: Icons.family; pixelSize: 19 }
                    MouseArea { cursorShape: Qt.PointingHandCursor; id: playArea; anchors { fill: parent; margins: -8 } hoverEnabled: true; onClicked: win.deckPlayPress() }
                }
                Text {
                    anchors { left: playBtn.right; leftMargin: 16; right: nextBtn.visible ? nextBtn.left : parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: win.deckInfo ? (win.deckInfo.title + "  —  " + win.deckInfo.artist)
                                       : (win.deckAlive ? "Deck — nothing playing" : "Deck — not running (press play to start)")
                    color: win.deckInfo === null ? Theme.dim : (win.deckPlaying ? Theme.accent : Theme.text)
                    font { family: Theme.font; pixelSize: win.fontSize - 3; weight: win.fontWeight }
                }
                Text {
                    id: nextBtn
                    visible: win.deckInfo !== null
                    anchors { right: heartBtn.visible ? heartBtn.left : parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    text: Icons.g("skip-forward")
                    color: nextArea.containsMouse ? Theme.accent : Theme.text
                    font { family: Icons.family; pixelSize: 17 }
                    MouseArea { cursorShape: Qt.PointingHandCursor; id: nextArea; anchors { fill: parent; margins: -8 } hoverEnabled: true; onClicked: win.deckCtl("next") }
                }
                Text {
                    id: heartBtn
                    visible: win.deckLiked !== null && win.deckLiked !== undefined
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    text: Icons.g("heart")
                    color: win.deckLiked ? Theme.primary : (heartArea.containsMouse ? Theme.accent : Theme.dim)
                    font { family: Icons.family; pixelSize: 17 }
                    MouseArea { cursorShape: Qt.PointingHandCursor; id: heartArea; anchors { fill: parent; margins: -8 } hoverEnabled: true; onClicked: win.deckCtl("like") }
                }
            }

            // Search field (+ path when in a sublevel)
            Row {
                width: parent.width
                height: 44
                Text {
                    id: crumb
                    visible: win.level !== "root"
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 14
                    rightPadding: 6
                    text: (win.titles[win.level] || win.level) + "  ›"
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: win.fontSize + 1; weight: win.fontWeight }
                }
                TextInput {
                    id: input
                    echoMode: win.level === "wifipw" ? TextInput.Password : TextInput.Normal   // Wi-Fi › Password
                    width: parent.width - (crumb.visible ? crumb.width : 0)
                    height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    leftPadding: crumb.visible ? 4 : 14
                    color: Theme.text
                    selectionColor: Theme.sel
                    font { family: Theme.font; pixelSize: win.fontSize + 2; weight: win.fontWeight }
                    focus: true
                    clip: true
                    onTextChanged: { if (win.detail !== null) { win.detail = null; win.detailInfo = null }   // a new search (IPC setQuery)
                                     win.query = text; win.armed = ""; win.playerFocused = false; list.currentIndex = win.firstSelectable() }
                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier
                        if (win.playerFocused && win.handlePlayerKey(event)) { event.accepted = true; return }
                        // ⌘C (Hyprland sends Ctrl+Insert; Ctrl+C too) on a row with a `copy` value, e.g. an IP address;
                        // selected text in the search field is copied as usual
                        const copyRow = win.results[list.currentIndex]
                        if (ctrl && (event.key === Qt.Key_Insert || event.key === Qt.Key_C) && copyRow && copyRow.copy !== undefined && selectedText === "") {
                            sys.copyText(copyRow.copy); event.accepted = true; return
                        }
                        if (win.detail !== null) {         // details: Enter installs / removes, arrows scroll, typing does nothing
                            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) win.back()
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.detailConfirm()
                            else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) win.detailSwitch()
                            else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) win.detailScroll(win.rowHeight)
                            else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) win.detailScroll(-win.rowHeight)
                            else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Space) win.detailScroll(detailView.height - win.rowHeight)
                            else if (event.key === Qt.Key_PageUp) win.detailScroll(-(detailView.height - win.rowHeight))
                            event.accepted = true
                            return
                        }
                        // Esc with a search typed clears it first (on any level); with an empty one it goes back / closes
                        if (event.key === Qt.Key_Escape) { if (text !== "") text = ""; else win.back(); event.accepted = true }
                        else if (ctrl && event.key === Qt.Key_Space) { win.deckPlayPress(); event.accepted = true }
                        else if (event.key === Qt.Key_Backspace && text === "" && win.level !== "root") { win.back(); event.accepted = true }
                        else if (win.grid && win.wallLoaded && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                            win.step(event.key === Qt.Key_Left ? -1 : 1); event.accepted = true
                        } else if (win.grid && win.wallLoaded && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
                            const i = list.currentIndex + (event.key === Qt.Key_Down ? win.gridCols : -win.gridCols)
                            if (i >= 0 && i < win.results.length) list.currentIndex = i
                            else if (i < 0) win.playerFocused = true
                            event.accepted = true
                        } else if (win.level === "baritems" && ctrl && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                            const cur = win.results[list.currentIndex]     // Items: the selected module moves, the selection with it
                            if (cur && cur.kind === "baritem" && win.query === "") {
                                const j = TopBar.move(cur.value, event.key === Qt.Key_Up ? -1 : 1)
                                Qt.callLater(() => { list.currentIndex = j })
                            } else shake.restart()
                            event.accepted = true
                        } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && (win.results[list.currentIndex] || {}).kind === "brightness") {
                            win.stepBright(event.key === Qt.Key_Left ? -1 : 1); event.accepted = true
                        } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && (win.results[list.currentIndex] || {}).kind === "slider") {
                            sys.stepSlider(win.results[list.currentIndex].key, event.key === Qt.Key_Left ? -1 : 1); event.accepted = true
                        } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) {
                            win.step(1); event.accepted = true
                        } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) {
                            win.step(-1); event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            const cur = win.results[list.currentIndex]
                            if (win.level === "passwords" && cur && cur.kind === "pw" && (event.modifiers & Qt.ShiftModifier)) win.copyField(cur, "username")
                            else if (win.level === "passwords" && cur && cur.kind === "pw" && ctrl) win.copyField(cur, "otp")
                            else if (win.selApp && ctrl) win.togglePin(cur)
                            else if (win.selApp && (event.modifiers & Qt.AltModifier)) win.toggleAutostart(cur)
                            else if (win.extLevel && cur && (event.modifiers & Qt.ShiftModifier)) win.extShift(cur)
                            else if (win.level === "clipboard" && cur && cur.kind === "clip" && (event.modifiers & Qt.ShiftModifier)) win.clipPick(cur, false)
                            else if (win.level === "emoji" && cur && cur.kind === "emoji" && (event.modifiers & Qt.ShiftModifier)) win.emojiPick(cur, false)
                            else if (cur && cur.kind === "sound" && (event.modifiers & Qt.ShiftModifier)) win.listenSound(cur)
                            else if (win.results.length === 0) shake.restart()
                            else win.activate(cur)
                            event.accepted = true
                        }
                    }
                }
            }

            ListView {
                id: list
                width: parent.width
                // On the grid level the list is hidden, but its currentIndex is still the selection (keys, Enter)
                visible: (!win.grid || !win.wallLoaded) && win.detail === null
                height: visible ? win.listHeight() : 0
                model: win.results
                clip: true
                currentIndex: 0
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                TouchScroll { view: list; step: win.rowHeight }
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool isHeader: modelData.kind === "header"
                    readonly property bool current: !isHeader && !win.playerFocused && index === list.currentIndex
                    readonly property bool noIcon: modelData.kind === "key" || modelData.kind === "hint" || modelData.kind === "header"
                    readonly property bool armedNow: (modelData.kind === "action" && modelData.confirm === true && win.armed === modelData.name)
                                                    || (modelData.armKey !== undefined && win.armed === modelData.armKey)
                    readonly property bool chevron: modelData.kind === "nav" || modelData.kind === "menu" || modelData.chevron === true
                    width: list.width
                    height: isHeader ? win.headerHeight : win.rowHeight
                    radius: 10
                    color: current ? Theme.sel : "transparent"

                    // Icon: app = image, root item = Lucide glyph, keybinding = no icon
                    Item {
                        id: slot
                        visible: !row.noIcon
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        width: win.iconSize; height: win.iconSize
                        AppIcon {
                            anchors.fill: parent
                            visible: (row.modelData.kind === "app" || row.modelData.iconFile !== undefined) && row.modelData.glyph === undefined && source !== ""
                            sourceSize: Qt.size(win.iconSize * 2, win.iconSize * 2)
                            name: row.modelData.iconFile !== undefined ? row.modelData.iconFile    // Install › Software
                                : row.modelData.kind === "app" ? (row.modelData.icon || "") : ""
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: row.modelData.emoji !== undefined
                            text: row.modelData.emoji !== undefined ? row.modelData.emoji : ""
                            font.pixelSize: win.iconSize - 6
                        }
                        Rectangle {      // Theme › Color: swatch (selected = border)
                            anchors.centerIn: parent
                            visible: row.modelData.swatch !== undefined
                            width: 20; height: 20; radius: 10
                            color: row.modelData.swatch || "transparent"
                            border.width: row.modelData.summary === "current" ? 2 : 0
                            border.color: Theme.accent
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: row.modelData.glyph !== undefined
                            text: row.modelData.glyph !== undefined ? Icons.g(row.modelData.glyph) : ""
                            color: row.modelData.dimmed ? Theme.dim : row.current ? Theme.accent : Theme.text
                            font { family: Icons.family; pixelSize: win.iconSize - 2 }
                        }
                    }
                    Text {
                        id: nameText
                        // A second line: an album's artist, or the description of an Install search result (row.modelData.sub)
                        readonly property bool twoLines: !!row.modelData.artist || !!row.modelData.sub
                        anchors {
                            left: row.noIcon ? parent.left : slot.right; leftMargin: 16
                            right: shortcut.visible ? shortcut.left : trailing.left; rightMargin: (row.modelData.kind === "key" ? 36 : 12) + (dot.visible ? 19 : 0) + (badge.visible ? badge.implicitWidth + 10 : 0)   // keybindings get more room before the keys (description is elided with …)
                            verticalCenter: parent.verticalCenter; verticalCenterOffset: twoLines ? (row.modelData.sub ? -9 : -7) : 0
                        }
                        elide: Text.ElideRight
                        // liveName: a name that changes often (Status' processes), bound here instead of rebuilding the rows
                        text: row.modelData.liveName !== undefined ? sys.liveText(row.modelData.liveName)
                            : row.isHeader ? row.modelData.name.toUpperCase()
                            : (row.armedNow ? row.modelData.name + " — " + (row.modelData.armHint || "press Enter again to confirm") : row.modelData.name)
                        color: row.armedNow ? Theme.primary : (row.isHeader ? Theme.primary : row.modelData.kind === "hint" || row.modelData.dimmed ? Theme.dim : (row.current ? Theme.accent : Theme.text))
                        font { family: Theme.font; pixelSize: row.isHeader ? win.fontSize - 5 : row.modelData.sub ? win.fontSize - 2 : win.fontSize; weight: row.isHeader ? Font.Bold : win.fontWeight; letterSpacing: row.isHeader ? 1.5 : 0 }
                        topPadding: row.isHeader ? 10 : 0
                    }
                    Text {
                        visible: nameText.twoLines
                        anchors { left: nameText.left; right: nameText.right; top: nameText.bottom; topMargin: row.modelData.sub ? 0 : -1 }
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: row.modelData.sub || (row.modelData.artist || "").toUpperCase()
                        color: row.modelData.sub ? Theme.dim : Theme.primary
                        font { family: Theme.font; pixelSize: row.modelData.sub ? win.fontSize - 5 : win.fontSize - 6; weight: row.modelData.sub ? win.fontWeight : Font.Normal
                               letterSpacing: row.modelData.sub ? 0 : 1 }
                    }
                    Rectangle {      // the row's shortcut (shortcutFor) in a key frame like the footer's, before the › of a submenu;
                        id: shortcut     // not where the right side is taken
                        readonly property string keys: !win.prefs.shortcuts || trailing.tag || row.modelData.keys !== undefined || row.armedNow
                            || (row.modelData.summary !== undefined && row.modelData.summary !== "") ? "" : win.shortcutFor(row.modelData)
                        visible: keys !== ""
                        anchors { right: trailing.left; rightMargin: trailing.text !== "" ? 18 : 0; verticalCenter: parent.verticalCenter }
                        width: shortcutText.implicitWidth + 14; height: 24; radius: 6
                        color: "transparent"
                        border { width: 1; color: Theme.dim }
                        Text {
                            id: shortcutText
                            anchors.centerIn: parent
                            text: shortcut.keys
                            color: Theme.dim
                            font { family: Theme.font; pixelSize: win.fontSize - 5 }
                        }
                    }
                    Text {
                        id: trailing
                        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        width: Math.min(implicitWidth, row.width * 0.42)
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignRight
                        // from = submenu a root-level search hit comes from (small violet tag)
                        readonly property bool tag: row.modelData.from !== undefined
                        readonly property bool glyphOnly: row.modelData.trailGlyph !== undefined
                            || (!tag && row.modelData.keys === undefined && !(row.modelData.summary !== undefined && row.modelData.summary !== "" && !row.armedNow) && row.chevron)
                        text: row.modelData.trailGlyph !== undefined ? Icons.g(row.modelData.trailGlyph)      // Top bar › Items: ✓ / – (hidden)
                            : row.modelData.live !== undefined ? sys.liveText(row.modelData.live)   // updates without rebuilding the rows
                            : tag ? row.modelData.from.toUpperCase() : row.modelData.keys !== undefined ? row.modelData.keys
                            : (row.modelData.summary !== undefined && row.modelData.summary !== "" && !row.armedNow ? row.modelData.summary
                            : (row.chevron ? Icons.g("chevron-right") : ""))
                        color: row.modelData.trailGlyph !== undefined ? (row.modelData.dimmed ? Theme.dim : row.current ? Theme.accent : Theme.text)
                             : tag ? Theme.primary : (row.modelData.keys !== undefined && row.current ? Theme.accent : Theme.dim)
                        font { family: glyphOnly ? Icons.family : Theme.font; pixelSize: glyphOnly ? win.iconSize - 6 : tag ? win.fontSize - 6 : row.modelData.kind === "album" ? win.fontSize - 5 : win.fontSize - 3
                               letterSpacing: tag ? 1 : 0 }   // tags: normal weight and spacing, the same as an album's artist
                    }
                    Rectangle {      // green dot right after the name: the app has a window open (including one hidden to the background by ⌘W)
                        id: dot
                        visible: win.appRunning(row.modelData)
                        x: nameText.x + Math.min(nameText.contentWidth, nameText.width) + 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9; height: 9; radius: 5
                        color: Theme.ok
                    }
                    Text {           // a small mark after the name (and the dot): row.modelData.badge, a Lucide name (Home: "pin")
                        id: badge
                        visible: row.modelData.badge !== undefined
                        x: nameText.x + Math.min(nameText.contentWidth, nameText.width) + 10 + (dot.visible ? 19 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        text: visible ? Icons.g(row.modelData.badge) : ""
                        color: Theme.primary   // the theme colour, like section headers: it has to stand out
                        font { family: Icons.family; pixelSize: win.fontSize - 2 }
                    }
                    Slider {         // Settings › Display › Brightness: above the row's MouseArea, so it gets the drag
                        visible: row.modelData.kind === "brightness" || row.modelData.kind === "slider"
                        z: 1
                        // after the name ("Screen" in Display, "Brightness" in a search), lined up while the name is short
                        anchors { left: slot.right; leftMargin: Math.max(120, 16 + nameText.implicitWidth + 28); right: trailing.left; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        value: row.modelData.kind === "slider" ? row.modelData.value : Math.max(0, win.bright)
                        dimmed: !!row.modelData.dimmed
                        trackColor: Qt.rgba(1, 1, 1, 0.1)   // the same on and off the selected row (Theme.border nearly matches Theme.sel)
                        onMoved: v => { list.currentIndex = row.index; row.modelData.kind === "slider" ? sys.setSlider(row.modelData.key, v) : win.setBright(v) }
                    }
                    MouseArea {
                        id: rowArea
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !row.isHeader
                        onPositionChanged: mouse => win.hover(rowArea, mouse, row.index)
                        onClicked: win.activate(row.modelData)
                    }
                }
            }

            // Install / Remove: a package's details. Header (icon, name, summary, button), facts, screenshot, description.
            Flickable {
                id: detailView
                readonly property var info: win.detailInfo
                readonly property var pkg: win.detail || ({})
                visible: win.detail !== null
                width: parent.width
                height: visible ? Math.min(contentHeight, win.maxRows * win.rowHeight + 60) : 0
                contentHeight: detailCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TouchScroll { view: detailView; step: win.rowHeight }

                Column {
                    id: detailCol
                    width: detailView.width
                    spacing: 18
                    topPadding: 4
                    bottomPadding: 6

                    Item {      // header
                        width: parent.width
                        height: Math.max(72, headText.implicitHeight)
                        Item {
                            id: headIcon
                            width: 64; height: 64
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            Image {
                                id: headImg
                                anchors.fill: parent
                                source: detailView.info && detailView.info.icon ? "file://" + detailView.info.icon
                                      : detailView.pkg.iconFile ? "file://" + detailView.pkg.iconFile : ""
                                sourceSize: Qt.size(128, 128)
                                fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: headImg.status !== Image.Ready
                                text: Icons.g(detailView.pkg.glyph || "package")
                                color: Theme.primary
                                font { family: Icons.family; pixelSize: 44 }
                            }
                        }
                        Column {
                            id: headText
                            anchors { left: headIcon.right; leftMargin: 20; right: button.left; rightMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 4
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                text: detailView.info ? detailView.info.name : (detailView.pkg.name || "")
                                color: Theme.accent
                                font { family: Theme.font; pixelSize: win.fontSize + 7; weight: Font.Normal }
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                text: detailView.info && detailView.info.summary ? detailView.info.summary : (detailView.pkg.summary || detailView.pkg.sub || "")
                                color: Theme.dim
                                font { family: Theme.font; pixelSize: win.fontSize - 2; weight: win.fontWeight }
                            }
                        }
                        Rectangle {      // Install / Remove (= Enter); grey when already installed
                            id: button
                            readonly property bool off: !detailView.pkg.remove && detailView.info !== null && detailView.info.installed
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            width: buttonRow.implicitWidth + 32
                            height: 40
                            radius: 10
                            color: off ? "transparent" : buttonArea.containsMouse ? Theme.primary : Theme.sel
                            border.width: off ? 1 : 0
                            border.color: Theme.border
                            Row {
                                id: buttonRow
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Icons.g(button.off ? "check" : detailView.pkg.remove ? "trash-2" : "download")
                                    color: button.off ? Theme.dim : buttonArea.containsMouse ? Theme.bg : Theme.accent
                                    font { family: Icons.family; pixelSize: 17 }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: button.off ? "Installed" : detailView.pkg.remove ? "Remove" : "Install"
                                    color: button.off ? Theme.dim : buttonArea.containsMouse ? Theme.bg : Theme.accent
                                    font { family: Theme.font; pixelSize: win.fontSize - 1; weight: Font.Normal }
                                }
                            }
                            MouseArea {
                                id: buttonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: button.off ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: win.detailConfirm()
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.border }

                    Text {
                        visible: detailView.info === null
                        leftPadding: 10
                        text: "Loading details…"
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: win.fontSize - 3; weight: win.fontWeight }
                    }

                    Grid {      // facts: label on the left, value on the right; the homepage opens in the browser
                        id: facts
                        visible: detailView.info !== null
                        x: 10
                        width: parent.width - 20
                        columns: 2
                        columnSpacing: 20
                        rowSpacing: 7
                        readonly property int labelWidth: 120
                        Repeater {
                            model: detailView.info ? detailView.info.fields.reduce((a, f) => a.concat([{ label: true, t: f[0] }, { label: false, t: f[1], link: f[0] === "Homepage" }]), []) : []
                            Text {
                                id: fact
                                required property var modelData
                                width: modelData.label ? facts.labelWidth : facts.width - facts.labelWidth - facts.columnSpacing
                                wrapMode: modelData.label ? Text.NoWrap : Text.WrapAtWordBoundaryOrAnywhere
                                textFormat: Text.PlainText
                                text: modelData.label ? modelData.t.toUpperCase() : modelData.t
                                color: modelData.label ? Theme.primary : modelData.link ? (linkArea.containsMouse ? Theme.accent : Theme.text) : Theme.text
                                font {
                                    family: Theme.font; pixelSize: modelData.label ? win.fontSize - 6 : win.fontSize - 3
                                    weight: win.fontWeight; letterSpacing: modelData.label ? 1 : 0; underline: !!modelData.link && linkArea.containsMouse
                                }
                                topPadding: modelData.label ? 3 : 0
                                MouseArea {
                                    id: linkArea
                                    enabled: !!fact.modelData.link
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: { win.open = false; Quickshell.execDetached(["xdg-open", fact.modelData.t]) }
                                }
                            }
                        }
                    }

                    ClippingRectangle {      // screenshot (from the internet; left out until it has loaded)
                        id: shotFrame
                        readonly property real ratio: shotImg.implicitWidth > 0 ? shotImg.implicitHeight / shotImg.implicitWidth : 0
                        visible: shotImg.status === Image.Ready
                        height: visible ? Math.min(360, parent.width * ratio) : 0
                        width: ratio > 0 ? Math.min(parent.width, height / ratio) : 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: 8
                        color: "transparent"
                        Image {
                            id: shotImg
                            anchors.fill: parent
                            source: detailView.info && detailView.info.screenshot ? detailView.info.screenshot : ""
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Column {      // description
                        visible: detailView.info !== null && detailView.info.paragraphs.length > 0
                        x: 10
                        width: parent.width - 20
                        spacing: 10
                        Repeater {
                            model: detailView.info ? detailView.info.paragraphs : []
                            Text {
                                required property string modelData
                                width: parent.width
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                lineHeight: 1.15
                                text: modelData
                                color: Theme.text
                                font { family: Theme.font; pixelSize: win.fontSize - 3; weight: win.fontWeight }
                            }
                        }
                    }
                }
            }

            // Settings › Background: previews in two columns, name below; current wallpaper marked with ✓
            GridView {
                id: wallGrid
                visible: win.grid && win.wallLoaded
                width: parent.width
                readonly property int thumbH: Math.round((cellWidth - 12) * 390 / 600)
                cellWidth: width / win.gridCols
                cellHeight: thumbH + 40
                height: visible ? Math.min(Math.ceil(win.results.length / win.gridCols) * cellHeight, 2.2 * cellHeight) : 0
                model: visible ? win.results : []
                currentIndex: win.playerFocused ? -1 : list.currentIndex
                highlightMoveDuration: 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TouchScroll { view: wallGrid; step: wallGrid.cellHeight }
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool current: !win.playerFocused && index === list.currentIndex
                    readonly property bool active: modelData.path === win.wallCurrent
                    width: wallGrid.cellWidth
                    height: wallGrid.cellHeight
                    Rectangle {
                        id: frame
                        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                        width: parent.width - 12
                        height: wallGrid.thumbH
                        radius: 8
                        color: Theme.bg
                        Text {
                            visible: cell.modelData.kind === "walladd"
                            anchors.centerIn: parent
                            text: Icons.g("plus")
                            color: cell.current ? Theme.accent : Theme.dim
                            font { family: Icons.family; pixelSize: 44 }
                        }
                        ClippingRectangle {      // preview with rounded corners (frame's inner radius)
                            anchors { fill: parent; margins: 3 }
                            radius: 6
                            color: "transparent"
                            Image {
                                anchors.fill: parent
                                source: cell.modelData.thumb ? "file://" + cell.modelData.thumb : ""
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 600
                            }
                        }
                        Rectangle {      // selection frame
                            anchors.fill: parent
                            radius: 8
                            color: "transparent"
                            border.width: cell.current ? 3 : 1
                            border.color: cell.current ? Theme.accent : Theme.border
                        }
                        Rectangle {      // current wallpaper
                            visible: cell.active
                            anchors { top: parent.top; right: parent.right; margins: 10 }
                            width: 26; height: 26; radius: 13
                            color: Theme.primary
                            Text {
                                anchors.centerIn: parent
                                text: Icons.g("check")
                                color: Theme.bg
                                font { family: Icons.family; pixelSize: 16 }
                            }
                        }
                    }
                    Text {
                        anchors { top: frame.bottom; topMargin: 6; left: frame.left; right: frame.right; leftMargin: 4; rightMargin: 4 }
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        readonly property bool armedNow: win.armed === "del:" + cell.modelData.path
                        text: armedNow ? "⌘⌫ again to delete" : cell.modelData.name + (cell.modelData.group ? "  ·  " + cell.modelData.group : "")
                        color: armedNow ? Theme.primary : cell.current ? Theme.accent : (cell.active ? Theme.text : Theme.dim)
                        font { family: Theme.font; pixelSize: win.fontSize - 3; weight: win.fontWeight }
                    }
                    MouseArea {
                        id: cellArea
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: mouse => win.hover(cellArea, mouse, cell.index)
                        onClicked: win.activate(cell.modelData)
                    }
                }
            }

            Row {
                visible: win.noHit
                anchors.right: parent.right
                rightPadding: 6
                spacing: 6
                Repeater {
                    model: ["command", "option", "corner-down-left"]
                    Rectangle {
                        required property string modelData
                        width: 22; height: 19; radius: 5
                        color: "transparent"
                        border.color: Theme.dim
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: Icons.g(parent.modelData)
                            color: Theme.dim
                            font { family: Icons.family; pixelSize: 12 }
                        }
                    }
                }
                Text {
                    text: "Send to Claude"
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: 12 }
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 3
                }
            }

            Row {      // footer: the keys of this level, as key caps + what they do
                visible: win.footer !== ""
                anchors.right: parent.right
                rightPadding: 6
                spacing: 18
                Repeater {
                    model: win.footerParts
                    Row {
                        id: part
                        required property var modelData
                        spacing: 4
                        Rectangle {      // one frame around the part's keys (⌃ ↵)
                            visible: part.modelData.keys.length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: caps.implicitWidth + 12; height: 22; radius: 6
                            color: "transparent"
                            border { width: 1; color: Theme.dim }
                            Row {
                                id: caps
                                anchors.centerIn: parent
                                spacing: 4
                                Repeater {
                                    model: part.modelData.keys
                                    Keycap { required property string modelData; key: modelData }
                                }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: part.modelData.keys.length ? 3 : 0
                            text: part.modelData.text.charAt(0).toUpperCase() + part.modelData.text.slice(1)
                            color: Theme.dim
                            font { family: Theme.font; pixelSize: 12 }
                        }
                    }
                }
            }
        }
    }
}
