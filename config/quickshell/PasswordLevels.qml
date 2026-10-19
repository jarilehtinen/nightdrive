import QtQuick
import Quickshell

// The launcher's Passwords (with 1Password, an optional part): the vault's items from the op CLI. Enter copies the
// password, Shift+Enter the username, Ctrl+Enter the one-time code. Secrets are marked as sensitive (cliphist doesn't
// store them in history) and cleared after 45 s.
// Launcher.qml asks it like DefaultAppsLevels (levels, titles, parents, items, activate, footer, entered), and also
// ctrlActivate (Ctrl+Enter).
Item {
    id: w
    property var launcher: null

    property var vault: []                    // 1Password items (op item list)
    property string status: "idle"            // idle | loading | ready | error
    property string error: ""

    readonly property var levels: ["passwords"]
    readonly property var titles: ({ passwords: "Passwords" })
    readonly property var parents: ({})

    function footer(level, query) { return status === "ready" ? "Enter: password  ·  Shift+Enter: username  ·  Ctrl+Enter: one-time code" : "" }
    function opened() {}
    function entered(level) { status = vault.length ? "ready" : "loading"; listProc.running = true }

    function items(level, q) {
        if (status === "loading" && vault.length === 0) return [{ kind: "hint", name: "Waiting for 1Password… (unlock it if prompted; Esc closes this menu)" }]
        if (status === "error") return error.split("\n").filter(l => l.trim() !== "").slice(0, 4).map(l => ({ kind: "hint", name: l }))
        return { all: vault.map(p => ({ item: p, text: p.name, extra: p.summary + " " + p.urls })) }
    }

    function activate(it) { if (it.kind !== "pw") return false; copyField(it, "password"); return true }
    function shiftActivate(it) { if (it.kind === "pw") copyField(it, "username"); else launcher.activate(it) }
    function ctrlActivate(it) { if (it.kind !== "pw") return false; copyField(it, "otp"); return true }

    // field → [message when missing, message when copied, secret (1 = sensitive + cleared after 45 s), op item get options...]
    readonly property var fields: ({
        password: ["No password field in this item", "Password copied", "1", "--fields", "label=password", "--reveal"],
        otp: ["No one-time password in this item", "One-time code copied", "1", "--otp"],
        username: ["No username in this item", "Username copied", "0", "--fields", "label=username"]
    })
    // Copies the field to the clipboard. Secrets are marked as sensitive (cliphist doesn't store them in history) and cleared after 45 s.
    function copyField(it, field) {
        launcher.open = false
        const script = 'id=$1 missing=$2 copied=$3 secret=$4; shift 4; ' +
            'v=$(op item get "$id" "$@" 2>/dev/null); [ -z "$v" ] && { notify-send -u critical "1Password" "$missing"; exit; }; ' +
            'if [ "$secret" = 1 ]; then printf %s "$v" | wl-copy --sensitive; notify-send -e -t 4000 "1Password" "$copied. Clears in 45 s"; sleep 45; ' +
            '[ "$(wl-paste -n 2>/dev/null)" = "$v" ] && wl-copy --clear; ' +
            'else printf %s "$v" | wl-copy; notify-send -e -t 3000 "1Password" "$copied"; fi'
        Quickshell.execDetached(["bash", "-c", script, "_", it.id].concat(fields[field] || fields.username))
    }

    // op item list (requires the 1Password app and CLI integration: Settings › Developer › Integrate with 1Password CLI)
    Sh {
        id: listProc
        script: 'op item list --format json 2>&1'
        onResult: text => {
            let arr = null
            try { arr = JSON.parse(text) } catch (e) {}
            if (!Array.isArray(arr) || listProc.exitCode !== 0) {
                const msg = text.trim().replace(/^\[ERROR\]\s*\d{4}\/\d\d\d\d?\/?\d* ?\d\d:\d\d:\d\d\s*/gm, "").split("\n")[0]
                const connect = /account|sign|integrat|connect|not found|no such/i.test(text)
                w.error = connect
                    ? "1Password CLI isn't connected.\nStart 1Password (⌘P) and unlock it, then open\nSettings › Developer › “Integrate with 1Password CLI”."
                    : (msg || "1Password CLI returned nothing")
                w.status = "error"
                return
            }
            const glyphs = { LOGIN: "key-round", PASSWORD: "lock-keyhole", SECURE_NOTE: "sticky-note", CREDIT_CARD: "credit-card",
                             IDENTITY: "user-round", API_CREDENTIAL: "terminal", SERVER: "server", WIRELESS_ROUTER: "wifi" }
            w.vault = arr.map(it => ({
                kind: "pw", id: it.id, name: it.title || "(untitled)",
                summary: it.additional_information || "",
                urls: (it.urls || []).map(u => u.href || "").join(" "),
                glyph: glyphs[it.category] || "key-round"
            })).sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()))
            w.status = "ready"
        }
    }
}
