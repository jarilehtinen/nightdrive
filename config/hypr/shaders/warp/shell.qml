// A home computer from 1982 in the desktop's colours: the desktop ripples back in time into it (warp.frag), it loads
// the first program on the disk with the loader's stripes in the border, and RUN starts a breakout game, title screen
// and tune included. 320×200 pixels, scaled by a whole number inside a border; the sound comes from ./sid. Its own
// Quickshell instance (qs -p this folder), over everything; Esc ends it. Started from the launcher's search, by a
// command only its hash gives away (Launcher.qml).
// You found it.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root
    readonly property int sw: 320
    readonly property int sh: 200
    readonly property real fill: 0.86         // the screen's share of the display at most; the rest is border
    readonly property int warpMs: 2600        // the trip back in time
    readonly property int bootMs: 900         // the command already typed (in the launcher) before it runs
    readonly property int searchMs: 1400      // SEARCHING FOR * before LOADING
    readonly property int loadMs: 4200        // the stripes
    readonly property int overMs: 2600        // GAME OVER before the title screen comes back
    readonly property string title: "NIGHTBREAK"
    readonly property string scrollText: "NIGHTBREAK ... A GAME FOR THE NIGHTDRIVE 64 ... MOVE THE PADDLE WITH THE MOUSE OR THE ARROWS, "
        + "SPACE OR A CLICK LAUNCHES THE BALL, P PAUSES, ESC ENDS IT ALL ... CATCH THE CAPSULES: E WIDENS THE PADDLE, "
        + "M MAKES THREE BALLS, S SLOWS THEM DOWN, C CATCHES, + IS ONE BALL MORE ... TEN LEVELS TO THE LAST NIGHT ... GREETINGS TO EVERYONE WHO STILL KNOWS WHAT LOAD\"*\",8,1 "
        + "MEANS ...          "
    // The loader's stripes: as loud as the real thing
    readonly property var stripes: ["#ff2a6d", "#ff9e3d", "#ffd319", "#05d9e8", "#5d6bff", "#c071eb", "#ffffff", "#ff6ec7",
                                    "#00ff9f", "#7b2ff7", "#000000", "#2de2e6", "#f6019d", "#fdfd96"]
    // Bricks by their letter in a level's map
    readonly property var brickColors: ({ a: "#ff2a6d", b: "#ff6ec7", c: "#ff9e3d", d: "#ffd319", e: "#05d9e8", f: "#5d6bff",
                                          g: "#c071eb", x: "#d8d4e8", "#": "#7d7891" })

    // Theme colours: a separate instance can't import ../../quickshell, so this reads the file Theme.qml reads
    property var c: ({})
    FileView {
        path: Quickshell.env("HOME") + "/.cache/nightdrive/theme.json"
        onLoaded: { try { root.c = JSON.parse(text()) } catch (e) {} }
    }
    readonly property color rim: c.primary || "#c071eb"   // the border
    readonly property color paper: c.deep || "#5c247b"      // the text screen
    readonly property color ink: c.accent || "#e0bff2"
    readonly property color night: Qt.darker(paper, 3.2)    // the game's background

    // 5×7 letters, drawn for this (the machine's own character set isn't free to copy), made bold below as that one is
    readonly property var font: ({
        "A": "00100 01010 10001 11111 10001 10001 10001", "B": "11110 10001 10001 11110 10001 10001 11110",
        "C": "01110 10001 10000 10000 10000 10001 01110", "D": "11100 10010 10001 10001 10001 10010 11100",
        "E": "11111 10000 10000 11110 10000 10000 11111", "F": "11111 10000 10000 11110 10000 10000 10000",
        "G": "01110 10001 10000 10111 10001 10001 01111", "H": "10001 10001 10001 11111 10001 10001 10001",
        "I": "01110 00100 00100 00100 00100 00100 01110", "J": "00111 00010 00010 00010 00010 10010 01100",
        "K": "10001 10010 10100 11000 10100 10010 10001", "L": "10000 10000 10000 10000 10000 10000 11111",
        "M": "10001 11011 10101 10101 10001 10001 10001", "N": "10001 10001 11001 10101 10011 10001 10001",
        "O": "01110 10001 10001 10001 10001 10001 01110", "P": "11110 10001 10001 11110 10000 10000 10000",
        "Q": "01110 10001 10001 10001 10101 10010 01101", "R": "11110 10001 10001 11110 10100 10010 10001",
        "S": "01111 10000 10000 01110 00001 00001 11110", "T": "11111 00100 00100 00100 00100 00100 00100",
        "U": "10001 10001 10001 10001 10001 10001 01110", "V": "10001 10001 10001 10001 10001 01010 00100",
        "W": "10001 10001 10001 10101 10101 10101 01010", "X": "10001 10001 01010 00100 01010 10001 10001",
        "Y": "10001 10001 10001 01010 00100 00100 00100", "Z": "11111 00001 00010 00100 01000 10000 11111",
        "0": "01110 10001 10011 10101 11001 10001 01110", "1": "00100 01100 00100 00100 00100 00100 01110",
        "2": "01110 10001 00001 00010 00100 01000 11111", "3": "11111 00010 00100 00010 00001 10001 01110",
        "4": "00010 00110 01010 10010 11111 00010 00010", "5": "11111 10000 11110 00001 00001 10001 01110",
        "6": "00110 01000 10000 11110 10001 10001 01110", "7": "11111 00001 00010 00100 01000 01000 01000",
        "8": "01110 10001 10001 01110 10001 10001 01110", "9": "01110 10001 10001 01111 00001 00010 01100",
        "*": "00000 00100 10101 01110 10101 00100 00000", "\"": "10010 10010 10010 00000 00000 00000 00000",
        ",": "00000 00000 00000 00000 01100 00100 01000", ".": "00000 00000 00000 00000 00000 01100 01100",
        "?": "01110 10001 00001 00010 00100 00000 00100", "!": "00100 00100 00100 00100 00100 00000 00100",
        "-": "00000 00000 00000 11111 00000 00000 00000", ":": "00000 01100 01100 00000 01100 01100 00000",
        "/": "00001 00010 00010 00100 01000 01000 10000", "+": "00000 00100 00100 11111 00100 00100 00000",
        "=": "00000 00000 11111 00000 11111 00000 00000", "$": "00100 01111 10100 01110 00101 11110 00100",
        "(": "00010 00100 01000 01000 01000 00100 00010", ")": "01000 00100 00010 00010 00010 00100 01000",
        " ": "00000 00000 00000 00000 00000 00000 00000"
    })
    // The same as pixel lists, [[x, y], …] per character, every stroke two pixels wide: 6×7 in the 8×8 cell
    readonly property var glyphs: {
        const out = {}
        for (const ch in font) {
            const px = []
            font[ch].split(" ").forEach((row, y) => {
                for (let x = 0; x < 6; x++) if (row[x] === "1" || row[x - 1] === "1") px.push([x + 1, y])
            })
            out[ch] = px
        }
        return out
    }

    // The levels: 19 bricks a row, . = none; a–g colours, x takes two hits, # never breaks
    readonly property var levels: [
        { name: "RAINBOW ROAD", map: [
            "...................",
            "aaaaaaaaaaaaaaaaaaa",
            "bbbbbbbbbbbbbbbbbbb",
            "ccccccccccccccccccc",
            "ddddddddddddddddddd",
            "eeeeeeeeeeeeeeeeeee",
            "fffffffffffffffffff",
            "ggggggggggggggggggg" ] },
        { name: "PYRAMID", map: [
            ".........a.........",
            "........aba........",
            ".......abcba.......",
            "......abcdcba......",
            ".....abcdedcba.....",
            "....abcdefedcba....",
            "...abcdefgfedcba...",
            "..xxxxxxxxxxxxxxx.." ] },
        { name: "CHECKERS", map: [
            "a.b.c.d.e.f.g.a.b.c",
            ".b.c.d.e.f.g.a.b.c.",
            "c.d.e.f.g.a.b.c.d.e",
            ".d.e.f.g.a.b.c.d.e.",
            "e.f.g.a.b.c.d.e.f.g",
            ".f.g.a.b.c.d.e.f.g.",
            "g.a.b.c.d.e.f.g.a.b",
            ".a.b.c.d.e.f.g.a.b.",
            "b.c.d.e.f.g.a.b.c.d" ] },
        { name: "SUNSET", map: [
            "......ccccccc......",
            "....ddddddddddd....",
            "...ccccccccccccc...",
            "...................",
            "..bbbbbbbbbbbbbbb..",
            "...................",
            ".aaaaaaaaaaaaaaaaa.",
            "...................",
            "###fffffffffffff###",
            "ggggggggggggggggggg" ] },
        { name: "FORTRESS", map: [
            "#.................#",
            "#.xxxxxxxxxxxxxxx.#",
            "#.xgggggggggggggx.#",
            "#.xfffffffffffffx.#",
            "#.xeeeeeeeeeeeeex.#",
            "#.xdddddddddddddx.#",
            "#.xxxxxxx.xxxxxxx.#",
            "#.................#",
            "###......#......###" ] },
        { name: "N", map: [
            "..g.....g...ffff...",
            "..gg....g...ffff...",
            "..g.g...g...ffff...",
            "..g..g..g...ffff...",
            "..g...g.g...ffff...",
            "..g....gg...ffff...",
            "..g.....g...ffff...",
            "...................",
            "aaaaaaaaaaaaaaaaaaa" ] },
        { name: "DIAMONDS", map: [
            "...a.....c.....e...",
            "..aaa...ccc...eee..",
            ".aaxaa.ccxcc.eexee.",
            "..aaa...ccc...eee..",
            "...a.....c.....e...",
            "...................",
            "b.b.b.b.b.b.b.b.b.b",
            ".d.d.d.d.d.d.d.d.d.",
            "xxxxxxxxxxxxxxxxxxx" ] },
        { name: "GATES", map: [
            "ggggggggggggggggggg",
            "fffffffffffffffffff",
            "###.###.###.###.###",
            "eeeeeeeeeeeeeeeeeee",
            "ddddddddddddddddddd",
            "#.###.###.###.###.#",
            "ccccccccccccccccccc",
            "bbbbbbbbbbbbbbbbbbb",
            "xxxxxxxxxxxxxxxxxxx" ] },
        { name: "WAVES", map: [
            "....a.......a......",
            "...a.a.....a.a.....",
            "..a...a...a...a...a",
            ".ae....a.ae....a.ae",
            "ae.e....ae.e....ae.",
            "e...e...e...e...e..",
            "c....e.ec....e.ec..",
            ".c....ec.c....ec.c.",
            "..c...c...c...c...c",
            "...c.c.....c.c.....",
            "....c.......c......",
            "x.x.x.x.x.x.x.x.x.x" ] },
        { name: "THE LAST NIGHT", map: [
            "xxxxxxxxxxxxxxxxxxx",
            "gfedcbagfedcbagfedc",
            "#.................#",
            "#.aaaaa.xxx.aaaaa.#",
            "#.bbbbb.xgx.bbbbb.#",
            "#.ccccc.xxx.ccccc.#",
            "#.................#",
            "dededededededededed",
            "xxxxxxxx###xxxxxxxx",
            "fffffffffffffffffff",
            "ggggggggggggggggggg" ] }
    ]

    // Capsules from broken bricks: E wider paddle, M three balls, S slower ball, C the paddle catches, + a ball more.
    // weight: how often each one falls, of all
    readonly property var powers: ({
        E: { color: "#5d6bff", weight: 25 }, M: { color: "#ff2a6d", weight: 25 }, S: { color: "#ff9e3d", weight: 20 },
        C: { color: "#05d9e8", weight: 20 }, "+": { color: "#ffffff", weight: 10 }
    })
    readonly property real dropChance: 0.13  // per broken brick
    readonly property real capsuleSpeed: 45  // px/s
    readonly property int maxBalls: 6

    // The play field (in the 320×200 screen)
    readonly property int wallL: 4
    readonly property int wallR: 316
    readonly property int wallT: 14
    readonly property int brickX: 8          // the first column's left edge
    readonly property int brickY: 24
    readonly property int padY: 186
    readonly property int padW: 32
    readonly property int padWide: 48       // with an E capsule
    readonly property int catchMs: 3000      // a caught ball leaves by itself after this
    readonly property int ball: 3
    readonly property real speed0: 120       // px/s at the start of the first level; each level adds levelSpeed
    readonly property real levelSpeed: 8
    readonly property real speedMax: 230
    readonly property real maxAngle: 62      // degrees from straight up, at the paddle's very edge

    // The text screen
    property var lines: ["", "    **** NIGHTDRIVE 64 BASIC V2 ****", "", " 64K RAM SYSTEM  38911 BASIC BYTES FREE", "", "READY."]
    property string input: ""
    property string phase: "warp"            // warp, boot, search, load, ready, title, game, over
    property real warpT: 0                   // ms of the trip, from the moment the desktop's picture is there
    property real phaseT: 0                  // ms in this phase
    property real clock: 0                   // ms since start (the cursor's blink)
    readonly property string bootCommand: 'LOAD"*",8,1'

    // The game, a plain object: it changes every frame, and only the canvas reads it
    property var g: null
    property real mouseX: -1
    property var held: ({})
    property int hiscore: 0
    property int lastScore: -1

    // The high score, kept between games
    FileView {
        id: hiFile
        path: Quickshell.env("HOME") + "/.local/state/nightdrive/nightbreak"
        printErrors: false
        onLoaded: root.hiscore = parseInt(text()) || 0
    }
    function saveHiscore() { hiFile.setText(String(hiscore) + "\n") }

    // The sound chip (./sid): commands one a line
    Process {
        id: sid
        command: [Qt.resolvedUrl("sid").toString().replace("file://", "")]
        stdinEnabled: true
        running: true
    }
    function sound(cmd) { if (sid.running) sid.write(cmd + "\n") }

    // The screen's rounded corners (a Hyprland shader, hyprland.lua) would draw over the border: hidden while this runs,
    // as the lock does
    function corners(hidden) { Quickshell.execDetached(["hyprctl", "eval", "NightdriveCornersHidden(" + hidden + ")"]) }
    Component.onCompleted: corners(true)
    function quit() { corners(false); Qt.quit() }

    function say(...more) { lines = lines.concat(more).slice(-24) }
    function to(p) { phase = p; phaseT = 0; border.requestPaint() }

    function run(command) {
        const cmd = command.replace(/\s+/g, "")
        if (cmd === "") return
        if (cmd === "RUN") { toTitle(); return }
        if (cmd.startsWith("LOAD")) { say("", "SEARCHING FOR " + (cmd.match(/"(.*?)"/) || [, "*"])[1]); to("search"); return }
        if (cmd === "LIST") { say("", "10 SYS 2061", "READY."); return }
        say("?SYNTAX  ERROR", "READY.")
    }

    function toTitle() { to("title"); sound("music title") }
    function newGame() {
        g = { score: 0, lives: 3, level: 0 }
        startLevel(0)
        to("game")
        sound("music off")
    }
    function startLevel(i) {
        g.level = i
        g.bricks = []
        levels[i].map.forEach((row, r) => row.split("").forEach((ch, col) => {
            if (ch !== ".") g.bricks.push({ x: brickX + col * 16, y: brickY + r * 8, ch: ch, hits: ch === "x" ? 2 : ch === "#" ? -1 : 1 })
        }))
        g.left = g.bricks.filter(b => b.hits > 0).length
        g.banner = 1800
        g.pad = (wallL + wallR - padW) / 2
        serve()
        sound("sfx start")
    }
    // A new ball on the paddle, and the paddle as it was: a level's start, or a lost ball
    function serve() {
        g.speed = speed0 + g.level * levelSpeed
        g.padW = padW
        g.catching = false
        g.caps = []
        g.balls = [{ x: 0, y: 0, vx: 0.5, vy: -0.866, stuck: true, off: padW / 2 - ball / 2, held: -Infinity }]
        g.paused = false
    }
    function launch() {
        if (phase === "title") newGame()
        else if (phase === "game" && g.banner <= 0 && !g.paused) for (const b of g.balls) b.stuck = false
    }

    function aim(b) {   // where it hits the paddle sets the angle
        const rel = Math.max(-1, Math.min(1, (b.x + ball / 2 - (g.pad + g.padW / 2)) / (g.padW / 2)))
        const a = rel * maxAngle * Math.PI / 180
        b.vx = Math.sin(a); b.vy = -Math.cos(a)
    }

    function power(type) {
        g.score += 100
        sound("sfx power")
        if (type === "E") { g.padW = padWide; g.catching = false; g.pad -= (padWide - padW) / 2 }
        else if (type === "C") { g.catching = true; g.padW = padW }
        else if (type === "S") g.speed = Math.max(speed0 * 0.7, g.speed * 0.6)
        else if (type === "+") g.lives = Math.min(g.lives + 1, 6)
        else if (type === "M") {
            const src = g.balls.find(b => !b.stuck) || g.balls[0]
            for (const turn of [-0.35, 0.35]) {
                if (g.balls.length >= maxBalls) break
                const c = Math.cos(turn), s = Math.sin(turn)
                g.balls.push({ x: src.x, y: src.y, vx: src.vx * c - src.vy * s, vy: src.vx * s + src.vy * c, stuck: false })
            }
        }
    }
    function drop(brick) {
        if (Math.random() > dropChance || g.caps.length >= 2) return
        let n = Math.random() * Object.values(powers).reduce((a, p) => a + p.weight, 0)
        for (const t in powers) {
            n -= powers[t].weight
            if (n <= 0) { g.caps.push({ x: brick.x, y: brick.y, type: t }); return }
        }
    }

    // One ball for this frame, in steps of at most a pixel so it can't pass through a brick. false: it fell out.
    function move(b, dt) {
        if (b.stuck) {
            b.x = g.pad + b.off; b.y = padY - ball
            if (b.held > -Infinity && now() - b.held > catchMs) { b.stuck = false; aim(b) }   // caught balls leave by themselves; the serve waits
            return true
        }
        let left = g.speed * dt / 1000
        while (left > 0) {
            const d = Math.min(1, left); left -= d
            const px = b.x, py = b.y
            b.x += b.vx * d; b.y += b.vy * d
            if (b.x < wallL) { b.x = wallL; b.vx = Math.abs(b.vx); sound("sfx wall") }
            if (b.x + ball > wallR) { b.x = wallR - ball; b.vx = -Math.abs(b.vx); sound("sfx wall") }
            if (b.y < wallT) { b.y = wallT; b.vy = Math.abs(b.vy); sound("sfx wall") }
            if (b.vy > 0 && b.y + ball >= padY && py + ball <= padY + 1 && b.x + ball >= g.pad && b.x <= g.pad + g.padW) {
                aim(b)
                b.y = padY - ball
                if (g.catching) { b.stuck = true; b.off = b.x - g.pad; b.held = now() }
                sound("sfx paddle")
                if (b.stuck) return true
            }
            // A brick: bounce off the side it was hit from
            const hit = g.bricks.find(k => k.hits !== 0 && b.x + ball > k.x && b.x < k.x + 15 && b.y + ball > k.y && b.y < k.y + 7)
            if (hit) {
                if (px + ball > hit.x && px < hit.x + 15) b.vy = -b.vy; else b.vx = -b.vx
                b.x = px; b.y = py
                if (hit.hits < 0) { sound("sfx steel"); continue }
                hit.hits--
                sound("sfx brick " + Math.round((hit.y - brickY) / 8))
                if (hit.hits === 0) { g.left--; g.score += hit.ch === "x" ? 50 : 10; drop(hit) }
                g.speed = Math.min(speedMax, g.speed + 1.2)
                if (g.left === 0) return true
            }
            if (b.y > sh) return false
        }
        return true
    }
    function now() { return clock }

    function step(dt) {
        if (g.paused) return
        if (g.banner > 0) g.banner -= dt
        // The paddle: the mouse (in screen pixels), or the arrows
        const keyDir = (held[Qt.Key_Right] ? 1 : 0) - (held[Qt.Key_Left] ? 1 : 0)
        if (keyDir !== 0) g.pad += keyDir * 220 * dt / 1000
        else if (mouseX >= 0) g.pad = mouseX - g.padW / 2
        g.pad = Math.max(wallL, Math.min(wallR - g.padW, g.pad))
        // Capsules fall; the paddle takes them
        for (const c of g.caps) {
            c.y += capsuleSpeed * dt / 1000
            if (c.y + 7 >= padY && c.y <= padY + 4 && c.x + 15 >= g.pad && c.x <= g.pad + g.padW) { c.taken = true; power(c.type) }
        }
        g.caps = g.caps.filter(c => !c.taken && c.y < sh)

        g.balls = g.balls.filter(b => move(b, dt))
        if (g.left === 0) {
            if (g.level + 1 < levels.length) startLevel(g.level + 1)
            else { g.won = true; to("over"); sound("sfx clear") }
        } else if (g.balls.length === 0) {
            g.lives--
            sound("sfx lose")
            if (g.lives === 0) to("over")
            else serve()
        }
    }

    function frame(dt) {
        dt = Math.min(dt, 50)   // a stall (the window opening) mustn't throw the ball through a wall
        clock += dt; phaseT += dt
        if (phase === "warp") {
            input = bootCommand
            if (past.hasContent) {
                if (warpT === 0) sound("sfx warp")
                warpT += dt
                if (warpT > warpMs) to("boot")
            } else if (phaseT > 800) to("boot")   // no picture of the desktop (no screencopy): straight to the machine
        } else if (phase === "boot") {
            input = bootCommand
            if (phaseT > bootMs) { say(input); input = ""; run(bootCommand) }
        } else if (phase === "search" && phaseT > searchMs) { say("LOADING"); to("load") }
        else if (phase === "load") {
            border.requestPaint()
            if (phaseT > loadMs) { say("READY."); to("ready") }
        } else if (phase === "game") step(dt)
        else if (phase === "over" && phaseT > overMs) {
            lastScore = g.score
            if (g.score > hiscore) { hiscore = g.score; saveHiscore() }
            toTitle()
        }
        display.requestPaint()
    }

    function key(e) {
        if (e.key === Qt.Key_Escape) { quit(); return }
        if (phase === "game") {
            if (e.key === Qt.Key_Space) launch()
            if (e.key === Qt.Key_P) g.paused = !g.paused
            if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) mouseX = -1   // the keys have it until the mouse moves
            held[e.key] = true
            return
        }
        if (phase === "title") { if (e.key === Qt.Key_Space || e.key === Qt.Key_Return) launch(); return }
        if (phase !== "ready") return
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { const t = input; say(t); input = ""; run(t.trim()) }
        else if (e.key === Qt.Key_Backspace) input = input.slice(0, -1)
        else {
            const ch = e.text.toUpperCase()
            if (ch.length === 1 && glyphs[ch] && input.length < 39) { input += ch; sound("sfx key") }
        }
    }

    function write(ctx, text, x, y, color) {
        ctx.fillStyle = color
        for (let i = 0; i < text.length; i++) {
            const px = glyphs[text[i]] || glyphs["?"]
            for (const p of px) ctx.fillRect(x + i * 8 + p[0], y + p[1], 1, 1)
        }
    }
    function centre(ctx, text, y, color) { write(ctx, text, Math.round((sw - text.length * 8) / 2), y, color) }
    // Big letters, s screen pixels a dot, each row of dots in its own colour (colorOf(row))
    function writeBig(ctx, text, x, y, s, colorOf) {
        for (let row = 0; row < 7; row++) {
            ctx.fillStyle = colorOf(row)
            for (let i = 0; i < text.length; i++)
                for (const p of glyphs[text[i]] || []) if (p[1] === row) ctx.fillRect(x + (i * 8 + p[0]) * s, y + row * s, s, s)
        }
    }

    // The title: the name in rolling colours, the scores, and a scroller with the instructions
    function paintTitle(ctx) {
        ctx.fillStyle = night; ctx.fillRect(0, 0, sw, sh)
        const roll = Math.floor(clock / 70)
        const big = 3
        writeBig(ctx, title, Math.round((sw - title.length * 8 * big) / 2), 34, big,
                 row => stripes[(row + roll) % 6])   // the first six stripes: the warm-to-cool run
        centre(ctx, "A GAME FOR THE NIGHTDRIVE 64", 72, ink)
        centre(ctx, "HI-SCORE " + String(hiscore).padStart(6, "0"), 100, "#ffffff")
        if (lastScore >= 0) centre(ctx, "LAST " + String(lastScore).padStart(6, "0"), 112, ink)
        if (Math.floor(clock / 500) % 2 === 0) centre(ctx, "PRESS SPACE OR CLICK", 136, stripes[3])
        // The scroller between two raster bars
        ctx.fillStyle = rim; ctx.fillRect(0, 170, sw, 2); ctx.fillRect(0, 184, sw, 2)
        const span = scrollText.length * 8 + sw
        const off = Math.floor(phaseT / 1000 * 48) % span
        const first = Math.max(0, Math.floor((off - sw) / 8))
        write(ctx, scrollText.slice(first, first + 42), sw - off + first * 8, 174, ink)
    }

    function paintText(ctx) {
        ctx.fillStyle = paper; ctx.fillRect(0, 0, sw, sh)
        const shown = lines.concat([input]).slice(-25)
        shown.forEach((l, r) => write(ctx, l, 0, r * 8, ink))
        const blink = Math.floor(clock / 330) % 2 === 0
        if ((phase === "ready" || phase === "boot") && blink) {
            ctx.fillStyle = ink
            ctx.fillRect(input.length * 8, (shown.length - 1) * 8, 8, 8)
        }
    }

    function paintGame(ctx) {
        ctx.fillStyle = night; ctx.fillRect(0, 0, sw, sh)
        ctx.fillStyle = paper   // the walls: the border's colour would make them vanish into it
        ctx.fillRect(0, wallT - 4, sw, 4)
        ctx.fillRect(0, wallT - 4, wallL, sh)
        ctx.fillRect(wallR, wallT - 4, sw - wallR, sh)
        write(ctx, "SCORE " + String(g.score).padStart(6, "0"), 0, 1, ink)
        write(ctx, "LEVEL " + (g.level + 1), 136, 1, ink)
        for (let i = 0; i < g.lives - 1; i++) { ctx.fillStyle = ink; ctx.fillRect(sw - 14 - i * 14, 3, 11, 3) }   // balls left
        for (const b of g.bricks) {
            if (b.hits === 0) continue
            const col = b.ch === "x" && b.hits === 1 ? Qt.darker(brickColors.x, 1.6) : brickColors[b.ch]
            ctx.fillStyle = col; ctx.fillRect(b.x, b.y, 15, 7)
            ctx.fillStyle = Qt.lighter(col, 1.35); ctx.fillRect(b.x, b.y, 15, 1)   // a lit top edge
            ctx.fillStyle = Qt.darker(col, 1.5); ctx.fillRect(b.x, b.y + 6, 15, 1)
            if (b.hits < 0) { ctx.fillStyle = Qt.lighter(col, 1.6); ctx.fillRect(b.x + 2, b.y + 2, 2, 2); ctx.fillRect(b.x + 11, b.y + 2, 2, 2) }   // rivets
        }
        for (const c of g.caps) {
            const col = powers[c.type].color
            ctx.fillStyle = col; ctx.fillRect(c.x + 1, c.y, 13, 7); ctx.fillRect(c.x, c.y + 1, 15, 5)
            write(ctx, c.type, c.x + 4, c.y, night)
        }
        const pad = Math.round(g.pad)
        ctx.fillStyle = ink; ctx.fillRect(pad, padY, g.padW, 4)
        ctx.fillStyle = g.catching ? powers.C.color : rim
        ctx.fillRect(pad, padY, 4, 4); ctx.fillRect(pad + g.padW - 4, padY, 4, 4)
        if (phase === "game") for (const b of g.balls) { ctx.fillStyle = "#ffffff"; ctx.fillRect(Math.round(b.x), Math.round(b.y), ball, ball) }
        if (phase === "over") centre(ctx, g.won ? "WELL DONE!" : "GAME OVER", 120, "#ffffff")
        else if (g.paused) centre(ctx, "PAUSED", 120, "#ffffff")
        else if (g.banner > 0) { centre(ctx, "LEVEL " + (g.level + 1), 120, "#ffffff"); centre(ctx, levels[g.level].name, 132, ink) }
        else if (g.balls.some(b => b.stuck && b.held === -Infinity) && Math.floor(clock / 500) % 2 === 0) centre(ctx, "SPACE OR CLICK", 160, ink)
    }

    FrameAnimation { running: true; onTriggered: root.frame(frameTime * 1000) }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) || Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nightdrive-basic"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        // See-through until the desktop's picture is taken, so the picture doesn't show this window
        color: root.phase === "warp" && !past.hasContent ? "transparent" : root.rim

        // The screen's size: a whole multiple of 320×200, so every pixel is the same size
        readonly property int k: Math.max(1, Math.floor(Math.min(width / root.sw, height / root.sh) * root.fill))

        // The desktop as it was, for the trip back
        ScreencopyView {
            id: past
            anchors.fill: parent
            captureSource: win.screen
            live: false
        }

        Item {
            id: machine
            anchors.fill: parent
            visible: root.phase !== "warp" || past.hasContent

            // The border: plain, or the loader's stripes (bands a screen pixel or several high, new ones every frame)
            Canvas {
                id: border
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d")
                    if (root.phase !== "load") { ctx.fillStyle = root.rim; ctx.fillRect(0, 0, width, height); return }
                    let y = 0
                    while (y < height) {
                        const h = win.k * (1 + Math.floor(Math.random() * 6))
                        ctx.fillStyle = root.stripes[Math.floor(Math.random() * root.stripes.length)]
                        ctx.fillRect(0, y, width, h)
                        y += h
                    }
                }
            }

            Canvas {
                id: display
                width: root.sw
                height: root.sh
                scale: win.k
                transformOrigin: Item.TopLeft
                x: Math.round((win.width - root.sw * win.k) / 2)
                y: Math.round((win.height - root.sh * win.k) / 2)
                smooth: false
                antialiasing: false
                onPaint: {
                    const ctx = getContext("2d")
                    if ((root.phase === "game" || root.phase === "over") && root.g) root.paintGame(ctx)
                    else if (root.phase === "title") root.paintTitle(ctx)
                    else root.paintText(ctx)
                }
            }
        }

        ShaderEffect {
            anchors.fill: parent
            visible: root.phase === "warp" && past.hasContent
            property variant source: ShaderEffectSource { sourceItem: past; hideSource: true }
            property variant target: ShaderEffectSource { sourceItem: machine }
            property real p: Math.min(1, root.warpT / root.warpMs)
            property real t: root.warpT / 1000
            property real blocks: win.k
            property size area: Qt.size(width, height)
            property color tint: root.rim
            fragmentShader: Qt.resolvedUrl("warp.frag.qsb")
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.BlankCursor
            onPositionChanged: mouse => root.mouseX = (mouse.x - display.x) / win.k
            onClicked: root.launch()
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => { if (!e.isAutoRepeat || root.phase !== "game") root.key(e); e.accepted = true }
            Keys.onReleased: e => { if (!e.isAutoRepeat) root.held[e.key] = false }
        }
    }
}
