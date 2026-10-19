import QtQuick
import Quickshell

// The launcher's Music (with Deck, an optional part): Album Shelf and Curated from Deck's files, and Search Spotify
// through Deck's own client, with an artist's albums. Enter on an album plays it in Deck. The root search finds the
// shelf's and Curated's albums too (rootRows). The player row above the search field stays in Launcher.qml.
// Launcher.qml asks it like DefaultAppsLevels (levels, titles, parents, items, activate, footer, entered).
Item {
    id: m
    property var launcher: null

    property var albums: []                   // Deck's shelf and Curated albums [{ uri, name, artist, year, list }]
    property var spotify: null                // Music › Search: { query, artists, albums, error } (deck search --json)
    property var artist: ({ id: "", name: "", albums: null })   // Music › Search › an artist's albums

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin"   // deck-ctl: plugins/deck/bin
    readonly property var levels: ["music", "shelf", "curated", "musicsearch", "artist"]
    readonly property var titles: ({ music: "Music", shelf: "Music › Album Shelf", curated: "Music › Curated", musicsearch: "Music › Search",
                                     artist: "Music › " + artist.name })
    readonly property var parents: ({ shelf: "music", curated: "music", musicsearch: "music", artist: "musicsearch" })

    function footer(level, query) { return level === "shelf" || level === "curated" ? "Enter: play in Deck" : "" }
    // Shelf and Curated are read on every open; a Spotify search is only kept while the launcher is open
    function opened() { spotify = null; if (launcher.hasDeck) musicProc.running = true }
    function entered(level) {}
    function shiftActivate(it) {}

    // An album row: the album's name with ARTIST below it (small, theme colour), the year on the right; an artist's own
    // album list leaves the artist out
    function albumItem(a, withArtist = true) {
        return { kind: "album", name: a.name, artist: withArtist && a.artist ? a.artist : "", summary: a.year ? String(a.year) : "", glyph: "disc-3", uri: a.uri }
    }
    // The root search's album rows ("fm-84" → Atlas): the MUSIC tag on the right instead of the year
    function rootRows() {
        if (!launcher.hasDeck) return []
        return albums.map(a => ({ item: Object.assign(albumItem(a), { summary: undefined, from: "Music" }), text: a.name, extra: a.artist }))
    }

    function items(level, q) {
        const hint = launcher.hint
        if (level === "music") {
            const count = list => albums.filter(a => a.list === list).length
            return { all: [{ kind: "nav", name: "Album Shelf", glyph: "library-big", target: "shelf", summary: String(count("shelf")) },
                           { kind: "nav", name: "Curated", glyph: "sparkles", target: "curated", summary: String(count("curated")) },
                           { kind: "nav", name: "Search Spotify", glyph: "search", target: "musicsearch", summary: "in Deck" }]
                .map(r => ({ item: r, text: r.name })) }
        }
        if (level === "musicsearch") {
            // Results come from `deck search --json` a moment after typing stops; going back from an artist shows them again
            const typed = launcher.query.trim()
            const shown = typed !== "" ? typed : (spotify ? spotify.query : "")
            if (shown === "") return hint("Type an artist or album")
            const inDeck = { kind: "decksearch", name: "Open “" + shown + "” in Deck", glyph: "external-link", value: shown }
            if (!spotify || spotify.query !== shown) return hint("Searching Spotify…")
            if (spotify.error) return hint(spotify.error).concat([inDeck])
            const artists = spotify.artists.slice(0, 4).map(a => ({ kind: "spotifyartist", name: a.name, glyph: "mic-vocal", id: a.id, chevron: true }))
            const found = spotify.albums.map(a => albumItem(a))
            if (artists.length + found.length === 0) return hint("Nothing found on Spotify").concat([inDeck])
            return (artists.length ? [{ kind: "header", name: "Artists" }].concat(artists) : [])
                .concat(found.length ? [{ kind: "header", name: "Albums" }].concat(found) : [], [inDeck])
        }
        if (level === "artist") {
            if (artist.albums === null) return hint("Loading albums…")
            if (artist.albums.length === 0) return hint("No albums found")
            return { all: artist.albums.map(a => ({ item: albumItem(a, false), text: a.name, extra: String(a.year || "") })) }
        }
        if (level === "shelf" || level === "curated") {
            const list = albums.filter(a => a.list === level)
            if (list.length === 0) return hint(level === "shelf" ? "The shelf is empty: add albums in Deck with a"
                                                                : "No Curated list yet: `deck curate` suggests albums based on what you play")
            return { all: list.map(a => ({ item: albumItem(a), text: a.name, extra: a.artist + " " + (a.year || "") })) }
        }
        return []
    }

    // Albums also come from the root search, so these work on any level
    function activate(it) {
        const l = launcher
        if (it.kind === "album") { l.open = false; Quickshell.execDetached([bin + "/deck-ctl", "play-album", it.uri]); return true }
        if (it.kind === "spotifyartist") {
            artist = { id: it.id, name: it.name, albums: null }
            artistProc.environment = { "ID": it.id }
            artistProc.running = true
            l.go("artist")
            return true
        }
        if (it.kind === "decksearch") { l.open = false; Quickshell.execDetached([bin + "/deck-ctl", "search", it.value]); return true }
        return false
    }

    // Deck's shelf (sorted by artist and year, like in Deck) and the Curated list
    Sh {
        id: musicProc
        script: 'd="$HOME/.config/deck"; s=$(cat "$d/shelf.json" 2>/dev/null || echo "[]"); c=$(cat "$d/curated.json" 2>/dev/null || echo "{}")
jq -cn --argjson s "$s" --argjson c "$c" \'[($s | sort_by((.artist | ascii_downcase), .year) | .[] | {uri, name, artist, year, list: "shelf"}),
  ($c.albums // [] | .[] | {uri, name, artist, year, list: "curated"})]\''
        onResult: text => { try { m.albums = JSON.parse(text) } catch (e) { m.albums = [] } }
    }
    // Music › Search: Spotify through Deck's own client (needs client_id in Deck's config.toml); one request after typing pauses
    Connections {
        target: m.launcher
        function onQueryChanged() { if (m.launcher.level === "musicsearch" && m.launcher.query.trim() !== "") spotifyDelay.restart() }
    }
    Timer { id: spotifyDelay; interval: 450; onTriggered: m.searchSpotify() }
    function searchSpotify() {
        const q = launcher.query.trim()
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
                m.spotify = { query: q, artists: r.artists || [], albums: r.albums || [], error: "" }
            } catch (e) { m.spotify = { query: q, artists: [], albums: [], error: String(e.message || e).replace(/^deck: /, "") } }
            const l = m.launcher
            if (l.level === "musicsearch" && l.query.trim() !== "" && l.query.trim() !== q) m.searchSpotify()   // typed on meanwhile
        }
    }
    Sh {
        id: artistProc
        script: '"$HOME/.local/bin/deck" artist-albums --json "$ID"'
        onResult: text => {
            let albums = []
            try { albums = JSON.parse(text) } catch (e) {}
            if (m.artist.id === artistProc.environment.ID) m.artist = Object.assign({}, m.artist, { albums: albums })
        }
    }
}
