import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Launcher (⌘Space). Player row above the search field while Deck is playing (Ctrl+Space = play/pause). Root level: Apps, Passwords, Clipboard, Screenshot, Keybindings, Settings, Install, Remove, Update, Power. Enter opens an item, Esc/Backspace (with an empty query) goes back,
// at the root level Esc closes. Up/down arrows or Ctrl+N/P/J/K move the selection.
// Apps: with an empty query, the allow-listed apps; when searching, also those hidden by sync-apps (hidden-apps.sh). See fuzzel/sync-apps, apps-allow.txt.
// ⌃Enter adds the selected app to Apps or removes it (your choice, ~/.local/state/nightdrive/apps.json).
// Keybindings: read from ~/.config/hypr/SHORTCUTS.md (the same file as the ⌘⇧K cheat sheet).
// Install › Package / Flatpak and Remove: Enter on a package opens its details in a wider card (hypr/scripts/pkg-info);
// there Enter installs or removes it, Esc goes back to the results.
PanelWindow {
    id: win

    // A key in the footer: Lucide glyph (Enter, Ctrl, ...) or its name (Esc) in a rounded frame
    component Keycap: Rectangle {
        property string key: ""
        readonly property string glyph: win.keyGlyphs[key] || ""
        width: Math.max(22, label.implicitWidth + 10); height: 19; radius: 5
        color: "transparent"
        border.color: Theme.dim
        border.width: 1
        Text {
            id: label
            anchors.centerIn: parent
            text: parent.glyph !== "" ? Icons.g(parent.glyph) : parent.key.toLowerCase()
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
    property var keyList: []                  // [{ name, keys, section }]
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
    property string idleStyle: ""             // which screensaver: random | saver | rain
    readonly property var saverStyles: [["random", "Random", "shuffle"], ["saver", "Synthwave", "sunset"], ["rain", "Rain", "cloud-rain"]]
    property int barOpacity: -1               // Settings › Top bar opacity: current value (hypr/scripts/bar-style), -1 = not read yet
    property string barIcons: ""              // Settings › Top bar icons: light | dark
    property int barIconOp: -1                // icon and text opacity
    property string barHl: ""                 // Settings › Theme › Top bar › Highlight: theme | white | black
    property int updates: 0                   // Update: new Nightdrive commits waiting (nightdrive update check, every 6 h)
    property var displays: null               // Settings › Display: [{ name, desc, scale, opts: [{ value, size }] }] (hypr/scripts/display list)
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
    readonly property bool extLevel: ext !== null && ext.levels.indexOf(level) >= 0
    readonly property var parents: Object.assign({ shelf: "music", curated: "music", musicsearch: "music", artist: "musicsearch", display: "settings", package: "install", flatpak: "install", webapp: "install", webname: "webapp", webaddr: "webname", theme: "settings", themecolor: "theme", background: "theme", topbar: "theme", startup: "settings", screensaver: "settings", saverafter: "screensaver", screenoff: "screensaver", saverstyle: "screensaver", baropacity: "topbar", baricons: "topbar", barhl: "topbar" }, ext ? ext.parents : {})
    // Search found nothing: hint below ⌘⌥⏎ (icons) → send the text to Claude
    readonly property bool noHit: (level === "root" || level === "apps") && query.trim() !== "" && results.length === 0
    // The selected row is an app: ⌃Enter adds it to Apps (shown with an empty query) or removes it from there
    readonly property var selApp: { const c = results[list.currentIndex]; return (level === "apps" || level === "root") && c && c.kind === "app" ? c : null }
    readonly property string footer: detail !== null ? (detail.remove ? "Enter: remove" : detailInfo && detailInfo.installed ? "Already installed" : "Enter: install")
                                                       + "  ·  Esc: back"
        : selApp ? "Enter: open  ·  Ctrl+Enter: " + (selApp.shown ? "remove from Apps" : "add to Apps")
                                              + "  ·  Alt+Enter: " + (autostartIds.indexOf(appId(selApp)) >= 0 ? "don’t start at login" : "start at login")
        : level === "startup" ? "Enter: start at login on/off  ·  background apps start hidden"
        : level === "passwords" && pwState === "ready" ? "Enter: password  ·  Shift+Enter: username  ·  Ctrl+Enter: one-time code"
        : extLevel ? ext.footer(level, query)
        : level === "clipboard" ? "Enter: paste  ·  Shift+Enter: copy only"
        : level === "shelf" || level === "curated" ? "Enter: play in Deck"
        : level === "emoji" ? "Enter: paste  ·  Shift+Enter: copy only  ·  search in English or Finnish"
        : level === "webname" && query.trim() !== "" ? "Enter: continue to the address"
        : level === "webaddr" && query.trim() !== "" ? "Enter: create the webapp" : ""
    // The footer as key caps: "Ctrl+Enter: add to Apps  ·  Esc: back" → [{ keys: ["Ctrl", "Enter"], text: "add to Apps" }, ...].
    // "Enter creates …" (no colon) works too; a part that doesn't start with a key is plain text.
    readonly property var keyGlyphs: ({ Enter: "corner-down-left", Ctrl: "chevron-up", Shift: "arrow-big-up", Alt: "option", Cmd: "command",
                                        Backspace: "delete", Space: "space" })
    readonly property var footerParts: footer === "" ? [] : footer.split(/\s+·\s+/).map(part => {
        const m = part.match(/^((?:Ctrl|Shift|Alt|Cmd|Enter|Esc|Tab|Space|Backspace)(?:\+(?:Ctrl|Shift|Alt|Cmd|Enter|Esc|Tab|Space|Backspace))*)(?::\s*|\s+)(.*)$/)
        return m ? { keys: m[1].split("+"), text: m[2] } : { keys: [], text: part }
    })
    property var lastMouse: null              // last mouse position (window coordinates); null = not seen yet since opening
    property var deckOverride: ({})           // pending local changes (playing, liked)
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts"
    readonly property string deckBin: Quickshell.env("HOME") + "/.local/bin/deck"
    readonly property bool deckPlaying: deckOverride.playing !== undefined ? deckOverride.playing : (deckInfo !== null && deckInfo.playing)
    readonly property var deckLiked: deckOverride.liked !== undefined ? deckOverride.liked : (deckInfo ? deckInfo.liked : null)
    signal openMenu(string name)              // Settings: opens a Quickshell menu (wifi, bluetooth, ...)

    readonly property var titles: Object.assign({ apps: "Apps", music: "Music", shelf: "Music › Album Shelf", curated: "Music › Curated", musicsearch: "Music › Search", artist: "Music › " + artist.name, keys: "Keybindings", screenshot: "Screenshot", settings: "Settings", display: "Settings › Display", startup: "Settings › Startup", screensaver: "Settings › Screensaver", saverafter: "Screensaver › Start after", screenoff: "Screensaver › Screen off after", saverstyle: "Screensaver › Style", theme: "Settings › Theme", themecolor: "Settings › Theme › Color", background: "Settings › Theme › Background",
                                     topbar: "Settings › Theme › Top bar", baropacity: "Theme › Top bar › Opacity", baricons: "Theme › Top bar › Icon colors", barhl: "Theme › Top bar › Highlight",
                                     install: "Install", emoji: "Emoji", package: "Install › Package", flatpak: "Install › Flatpak", webapp: "Install › Webapp", webname: "Install › Webapp › Name", webaddr: "Install › Webapp › Address", remove: "Remove", power: "Power", passwords: "Passwords", clipboard: "Clipboard",
                                     tools: "Tools" }, ext ? ext.titles : {})

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
        { kind: "nav", name: "Emoji", glyph: "smile", target: "emoji" },
        { kind: "nav", name: "Screenshot", glyph: "camera", target: "screenshot" },
        { kind: "nav", name: "Music", glyph: "disc-3", target: "music" },
    ].concat(ext ? ext.rootItems : [], [
        { kind: "nav", name: "Tools", glyph: "wrench", target: "tools" },
        { kind: "nav", name: "Keybindings", glyph: "keyboard", target: "keys" },
        { kind: "nav", name: "Settings", glyph: "settings", target: "settings" },
        { kind: "nav", name: "Install", glyph: "package-plus", target: "install" },
        { kind: "nav", name: "Remove", glyph: "package-minus", target: "remove" },
        { kind: "action", name: "Update", glyph: "refresh-cw", confirm: true, cmd: term('"$HOME/.local/bin/nightdrive" update'),
          summary: updates > 0 ? updates + " new" : undefined },
        { kind: "nav", name: "Power", glyph: "power", target: "power" }
    ])

    // Static sublevels
    readonly property var statics: ({
        tools: [
            { kind: "action", name: "Color Picker", glyph: "pipette", cmd: ["bash", "-c", "sleep 0.4; \"$HOME/.config/hypr/scripts/color-picker\""] }
        ],
        screenshot: [
            { kind: "action", name: "Region", glyph: "crop", cmd: shot("region") },
            { kind: "action", name: "Window", glyph: "app-window", cmd: shot("window") },
            { kind: "action", name: "Full screen", glyph: "monitor", cmd: shot("full") }
        ],
        install: [
            { kind: "nav", name: "Package", glyph: "package-plus", target: "package", summary: "dnf" },
            { kind: "nav", name: "Flatpak", glyph: "store", target: "flatpak", summary: "apps from Flathub" },
            { kind: "nav", name: "Webapp", glyph: "app-window", target: "webapp", summary: "website as an app" }
        ],
        webapp: [
            { kind: "nav", name: "Name and address here", glyph: "keyboard", target: "webname" },
            { kind: "action", name: "In a terminal", glyph: "terminal", cmd: webappTerm() }
        ],
        settings: [
            { kind: "menu", name: "Wi-Fi", glyph: "wifi", target: "wifi" },
            { kind: "menu", name: "Bluetooth", glyph: "bluetooth", target: "bluetooth" },
            { kind: "menu", name: "Sound", glyph: "volume-2", target: "volume" },
            { kind: "menu", name: "Battery & display", glyph: "battery-medium", target: "battery" },
            { kind: "nav", name: "Display", glyph: "monitor", target: "display" },
            { kind: "nav", name: "Screensaver", glyph: "monitor-pause", target: "screensaver" },
            { kind: "nav", name: "Startup", glyph: "rocket", target: "startup" },
            { kind: "menu", name: "Tailscale", glyph: "shield-check", target: "tailscale" },
            { kind: "nav", name: "Theme", glyph: "palette", target: "theme" }
        ],
        power: [
            { kind: "action", name: "Lock", glyph: "lock", cmd: ["loginctl", "lock-session"] },
            { kind: "action", name: "Sleep", glyph: "moon", cmd: ["systemctl", "suspend"] },
            { kind: "action", name: "Log out", glyph: "log-out", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
            { kind: "action", name: "Restart", glyph: "rotate-cw", confirm: true, cmd: ["systemctl", "reboot"] },
            { kind: "action", name: "Shut down", glyph: "power", confirm: true, cmd: ["systemctl", "poweroff"] }
        ]
    })

    readonly property var settingsAliases: ({ "Wi-Fi": "wifi wlan network internet", "Sound": "audio volume output speakers", "Battery & display": "power brightness screen",
                                              "Display": "scale scaling resolution monitor screen retina hidpi zoom size bigger smaller",
                                              "Tailscale": "vpn", "Theme": "appearance style look colors",
                                              "Color": "theme accent violet purple blue teal green amber rose graphite gray",
                                              "Background": "wallpaper desktop image picture",
                                              "Top bar": "waybar panel menu bar",
                                              "Opacity": "top bar waybar panel transparency transparent",
                                              "Icon colors": "top bar waybar panel white black light dark text",
                                              "Highlight": "top bar waybar panel active workspace" })
    // Settings › Theme: sub-items (Color with its current value)
    function themeItems() {
        const cur = themeList.find(t => t.current)
        return [
            { kind: "nav", name: "Color", glyph: "palette", target: "themecolor", summary: cur ? cur.name.toLowerCase() : undefined },
            { kind: "nav", name: "Background", glyph: "wallpaper", target: "background" },
            { kind: "nav", name: "Top bar", glyph: "panel-top", target: "topbar" }
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
    // Settings › Theme › Top bar: sub-items with their current values
    function topbarItems() {
        return [
            { kind: "nav", name: "Opacity", glyph: "panel-top", target: "baropacity", summary: barOpacity >= 0 ? barOpacity + "%" : undefined },
            { kind: "nav", name: "Icon colors", glyph: "contrast", target: "baricons",
              summary: barIcons !== "" ? (barIcons === "dark" ? "black" : "white") + " " + barIconOp + "%" : undefined },
            { kind: "nav", name: "Highlight", glyph: "highlighter", target: "barhl",
              summary: barHl === "theme" ? "theme color" : (barHl || undefined) }
        ]
    }
    readonly property var powerAliases: ({ "Lock": "screen", "Sleep": "suspend", "Log out": "logout sign out exit", "Restart": "reboot", "Shut down": "shutdown poweroff power off" })

    // 0 = starts with query, 1 = word start, 2 = contains, -1 = no match
    function score(text, q) {
        const t = text.toLowerCase()
        if (t.startsWith(q)) return 0
        if (t.split(/[\s\-_.\/]+/).some(w => w.startsWith(q))) return 1
        if (t.includes(q)) return 2
        return -1
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
        if (i >= 0 && i < results.length) list.currentIndex = i
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
            all = rootItems.map(r => ({ item: r, text: r.name }))
            // When searching, the root level also finds rows from the sublevels, so there's no need to open a menu first.
            // "from" tells which menu a row comes from; extra adds search words (aliases, alternative spellings).
            if (q !== "") for (const src of [
                // Tools entries ("color" → Color Picker)
                statics.tools.map(t => ({ item: t, text: t.name })),
                // Screenshot actions ("region", "screenshot", "capture")
                statics.screenshot.map(t => ({ item: Object.assign({}, t, { from: "Screenshot" }), text: t.name, extra: "screenshot capture screen" })),
                // Settings items ("wallpaper" → Background, "wifi" → Wi-Fi) plus Theme and Top bar sub-items ("opacity")
                statics.settings.map(t => ({ item: Object.assign({}, t, { from: "Settings" }), text: t.name, extra: "settings " + (settingsAliases[t.name] || "") })),
                themeItems().map(t => ({ item: Object.assign({}, t, { from: "Theme", summary: undefined }), text: t.name, extra: "theme " + (settingsAliases[t.name] || "") })),
                topbarItems().map(t => ({ item: Object.assign({}, t, { from: "Top bar", summary: undefined }), text: t.name, extra: settingsAliases[t.name] || "" })),
                // Power actions ("shut" → Shut down)
                statics.power.map(t => ({ item: t, text: t.name, extra: powerAliases[t.name] || "" })),
                // Apps ("1pas" → 1Password), also one named like a root item (e.g. a webapp next to its menu): the APPS tag and
                // the open-window dot tell them apart
                appEntries(q).map(a => Object.assign({}, a, { item: Object.assign({}, a.item, { from: "Apps" }) })),
                // Deck's albums ("fm-84" → Atlas)
                // (the MUSIC tag on the right instead of the year)
                musicAlbums.map(a => ({ item: Object.assign(albumItem(a), { summary: undefined, from: "Music" }), text: a.name, extra: a.artist }))
            ]) all = all.concat(src)
        } else if (level === "apps") {
            all = appEntries(q)
            if (q === "") all.sort((a, b) => a.text.localeCompare(b.text))
        } else if (level === "keys") {
            all = keyList.map(k => ({ item: { kind: "key", name: k.name, keys: k.keys, section: k.section }, text: k.name, extra: k.keys + " " + k.section }))
        } else if (level === "package" || level === "flatpak") {
            const what = level === "flatpak" ? "apps" : "packages"
            if (q.replace(/[^a-z0-9._+\-]/g, "").length < 2) return [{ kind: "hint", name: "Type at least 2 characters to search " + what }]
            if (installResults.length === 0) return [{ kind: "hint", name: installProc.running || flatpakProc.running ? "Searching…" : "No " + what + " found" }]
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
        } else if (extLevel) {
            const r = ext.items(level, q)
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
            // Scales the panel divides evenly, shown as the resulting desktop size ("looks like" in macOS); current one marked
            if (displays === null) return hint("Loading…")
            const out = []
            for (const d of displays) {
                if (displays.length > 1) out.push({ kind: "header", name: d.name + (d.desc !== "-" ? "  " + d.desc : "") })
                for (const o of d.opts) {
                    const cur = Math.abs(o.value - d.scale) < 0.01
                    out.push({ kind: "scale", output: d.name, value: o.value, name: o.size, glyph: cur ? "check" : "monitor",
                               summary: (cur ? "current · " : "") + "scale " + +o.value.toFixed(2) })
                }
            }
            return out
        } else if (level === "theme") {
            all = themeItems().map(t => ({ item: t, text: t.name, extra: settingsAliases[t.name] || "" }))
        } else if (level === "themecolor") {
            if (themeList.length === 0) return [{ kind: "hint", name: "Loading…" }]
            all = themeList.map(t => ({ item: { kind: "themecolor", value: t.value, name: t.name, swatch: t.swatch,
                                               summary: t.current ? "current" : (t.value === "violet" ? "default" : undefined) }, text: t.name }))
        } else if (level === "screensaver") {
            all = screensaverItems().map(t => ({ item: t, text: t.name }))
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
        } else if (level === "remove") {
            if (!removeLoaded) return [{ kind: "hint", name: "Loading packages…" }]
            all = removeList.map(p => ({ item: p, text: p.name, extra: p.summary }))
        } else {
            all = (statics[level] || []).map(r => ({ item: r, text: r.name }))
        }
        if (q === "") return level === "keys" ? grouped(all.map(x => x.item)) : all.map(x => x.item)
        const scored = []
        all.forEach((x, i) => {
            let s = score(x.text, q)
            if (s < 0 && x.extra && x.extra.toLowerCase().includes(q)) s = 3
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
        if (target === "emoji" && !emojiLoaded) emojiProc.running = true
        if (target === "clipboard") { clipLoaded = false; clipProc.running = true }
        if (target === "background") wallProc.running = true
        if (target === "topbar" || target === "baropacity" || target === "baricons" || target === "barhl") barProc.running = true
        if (target === "theme" || target === "themecolor") themeProc.running = true
        if (target === "display") displayProc.running = true
        if (target === "screensaver" || target === "saverafter" || target === "screenoff" || target === "saverstyle") idleProc.running = true
        if (ext && ext.levels.indexOf(target) >= 0) ext.entered(target)
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
                Quickshell.execDetached([scripts + "/launch-or-focus", bgApps[item.name], "gtk-launch", item.entry.id])
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
        else if (item.kind === "scale") {     // stays open like the theme rows; Hyprland reloads with the new scale
            keepSelection()
            displays = displays.map(d => d.name === item.output ? Object.assign({}, d, { scale: item.value }) : d)
            Quickshell.execDetached([scripts + "/display", "scale", item.output, String(item.value)])
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
        ext.shiftActivate(item)
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
    function keepSelection() { const i = list.currentIndex; Qt.callLater(() => { list.currentIndex = i }) }
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
    else { lastMouse = null; spotify = null; lastSel = ({}); if (ext) ext.opened(); go("root"); deckProc.running = true; musicProc.running = true; bgProc.running = true; bgAppsProc.running = true; autostartProc.running = true; updatesProc.running = true; input.forceActiveFocus() }
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

    // Install: dnf or Flathub search while typing (300 ms delay), max 30 results
    function sanitized() { return query.trim().toLowerCase().replace(/[^a-z0-9._+\-]/g, "") }
    function runSearch() {
        const q = sanitized()
        installQ = q
        if (q.length < 2) { installResults = []; return }
        const proc = level === "flatpak" ? flatpakProc : installProc
        proc.environment = { "Q": q }
        proc.running = true
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
        if (level === "package" || level === "flatpak") { armed = ""; searchDelay.restart() }
        if (level === "musicsearch" && query.trim() !== "") spotifyDelay.restart()
    }
    Timer { id: searchDelay; interval: 300; onTriggered: win.runSearch() }
    Sh {
        id: installProc
        script: 'dnf repoquery --available -q --latest-limit=1 --queryformat "%{name}|%{summary}\\n" "*$Q*" 2>/dev/null | head -80'
        onResult: text => {
            if (win.level !== "package") return   // left the level while searching
            const seen = {}, out = []
            for (const p of win.parsePackages(text)) {
                if (seen[p.name]) continue
                seen[p.name] = true
                out.push({ kind: "action", name: p.name, sub: p.summary, glyph: "package-plus", src: "dnf", id: p.name,
                           cmd: win.term('sudo dnf install "$1"', p.name) })
            }
            const q = win.installQ
            out.sort((a, b) => (b.name.startsWith(q) - a.name.startsWith(q)) || a.name.length - b.name.length || a.name.localeCompare(b.name))
            win.installResults = out.slice(0, 30)
            if (win.level === "package" && win.sanitized() !== win.installQ) win.runSearch()   // the query went stale meanwhile
        }
    }
    // Flathub has runtimes and extensions too; only apps are installable on their own, and their ids don't look like these
    Sh {
        id: flatpakProc
        script: 'flatpak search --columns=application,name,description,remotes "$Q" 2>/dev/null | grep -P "\\tflathub" | grep -vE "^\\S*\\.(Platform|Sdk|BaseApp|Extension|Plugin|Plugins|Codecs|GL|Gtk3theme)(\\.|\\s)" | head -80'
        onResult: text => {
            if (win.level !== "flatpak") return
            const out = []
            for (const line of text.split("\n")) {
                const [id, name, desc] = line.split("\t")
                if (!name) continue
                out.push({ kind: "action", name: name, sub: desc + "  ·  " + id, glyph: "store", src: "flatpak", id: id,
                           cmd: win.term('flatpak install --user flathub "$1"', id) })
            }
            const q = win.installQ
            out.sort((a, b) => (b.name.toLowerCase().startsWith(q) - a.name.toLowerCase().startsWith(q)))
            win.installResults = out.slice(0, 30)
            if (win.sanitized() !== win.installQ) win.runSearch()
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
            win.displays = text.split("\n").map(l => l.split("\t")).filter(f => f.length >= 4).map(f => ({
                name: f[0], desc: f[1], scale: parseFloat(f[2]),
                opts: f.slice(3).map(o => { const [v, size] = o.split(":"); return { value: parseFloat(v), size: size.replace("×", " × ") } }) }))
            if (win.level === "display" && win.query === "") win.selectWhere(r => r.kind === "scale" && r.summary.startsWith("current"))
        }
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

    // SHORTCUTS.md → [{ name, keys, section }]
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
                if (m && section) out.push({ keys: m[1].trim(), name: m[2].trim(), section: section })
            }
            win.keyList = out
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
        function deleteSelected(): void { if (win.open && win.level === "background" && win.wallLoaded) win.deleteWall() }
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
                    width: parent.width - (crumb.visible ? crumb.width : 0)
                    height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    leftPadding: crumb.visible ? 4 : 14
                    color: Theme.text
                    selectionColor: Theme.sel
                    font { family: Theme.font; pixelSize: win.fontSize + 2; weight: win.fontWeight }
                    focus: true
                    clip: true
                    onTextChanged: { win.query = text; win.armed = ""; win.playerFocused = false; list.currentIndex = win.firstSelectable() }
                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier
                        if (win.playerFocused && win.handlePlayerKey(event)) { event.accepted = true; return }
                        if (win.detail !== null) {         // details: Enter installs / removes, arrows scroll, typing does nothing
                            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) win.back()
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.detailConfirm()
                            else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) win.detailScroll(win.rowHeight)
                            else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) win.detailScroll(-win.rowHeight)
                            else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Space) win.detailScroll(detailView.height - win.rowHeight)
                            else if (event.key === Qt.Key_PageUp) win.detailScroll(-(detailView.height - win.rowHeight))
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Escape) { win.back(); event.accepted = true }
                        else if (ctrl && event.key === Qt.Key_Space) { win.deckPlayPress(); event.accepted = true }
                        else if (event.key === Qt.Key_Backspace && text === "" && win.level !== "root") { win.back(); event.accepted = true }
                        else if (win.grid && win.wallLoaded && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                            win.step(event.key === Qt.Key_Left ? -1 : 1); event.accepted = true
                        } else if (win.grid && win.wallLoaded && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
                            const i = list.currentIndex + (event.key === Qt.Key_Down ? win.gridCols : -win.gridCols)
                            if (i >= 0 && i < win.results.length) list.currentIndex = i
                            else if (i < 0) win.playerFocused = true
                            event.accepted = true
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
                        Image {
                            anchors.fill: parent
                            visible: row.modelData.kind === "app" && row.modelData.glyph === undefined && source !== ""
                            sourceSize: Qt.size(win.iconSize * 2, win.iconSize * 2)
                            fillMode: Image.PreserveAspectFit
                            source: row.modelData.kind === "app" ? Quickshell.iconPath(row.modelData.icon, true) : ""
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
                            color: row.current ? Theme.accent : Theme.text
                            font { family: Icons.family; pixelSize: win.iconSize - 2 }
                        }
                    }
                    Text {
                        id: nameText
                        // A second line: an album's artist, or the description of an Install search result (row.modelData.sub)
                        readonly property bool twoLines: !!row.modelData.artist || !!row.modelData.sub
                        anchors {
                            left: row.noIcon ? parent.left : slot.right; leftMargin: 16
                            right: trailing.left; rightMargin: (row.modelData.kind === "key" ? 36 : 12) + (dot.visible ? 19 : 0)   // keybindings get more room before the keys (description is elided with …)
                            verticalCenter: parent.verticalCenter; verticalCenterOffset: twoLines ? (row.modelData.sub ? -9 : -7) : 0
                        }
                        elide: Text.ElideRight
                        text: row.isHeader ? row.modelData.name.toUpperCase()
                            : (row.armedNow ? row.modelData.name + " — " + (row.modelData.armHint || "press Enter again to confirm") : row.modelData.name)
                        color: row.armedNow ? Theme.primary : (row.isHeader ? Theme.primary : row.modelData.kind === "hint" ? Theme.dim : (row.current ? Theme.accent : Theme.text))
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
                    Text {
                        id: trailing
                        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        width: Math.min(implicitWidth, row.width * 0.42)
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignRight
                        // from = submenu a root-level search hit comes from (small violet tag)
                        readonly property bool tag: row.modelData.from !== undefined
                        readonly property bool glyphOnly: !tag && row.modelData.keys === undefined && !(row.modelData.summary !== undefined && row.modelData.summary !== "" && !row.armedNow) && row.chevron
                        text: tag ? row.modelData.from.toUpperCase() : row.modelData.keys !== undefined ? row.modelData.keys
                            : (row.modelData.summary !== undefined && row.modelData.summary !== "" && !row.armedNow ? row.modelData.summary
                            : (row.chevron ? Icons.g("chevron-right") : ""))
                        color: tag ? Theme.primary : (row.modelData.keys !== undefined && row.current ? Theme.accent : Theme.dim)
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
                                source: detailView.info && detailView.info.icon ? "file://" + detailView.info.icon : ""
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
                        Repeater {
                            model: part.modelData.keys
                            Keycap { required property string modelData; key: modelData }
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
