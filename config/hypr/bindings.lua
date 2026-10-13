-- All Hyprland keybindings (⌘ = SUPER).
-- Edit this file; Hyprland reloads changes automatically.
-- App-specific keys live in each app's own config (e.g. ~/.config/kitty/kitty.conf).

---------------------
---- PROGRAMS ----
---------------------
local terminal    = "kitty --directory " .. os.getenv("HOME") .. "/Projects"
local browser     = "firefox"
local fileManager = "nautilus"
local scripts     = os.getenv("HOME") .. "/.config/hypr/scripts"


------------------------
---- KEYBINDINGS ----
------------------------
local mod = "SUPER"

-- Programs
hl.bind(mod .. " + RETURN",      hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + ALT + RETURN", hl.dsp.exec_cmd(scripts .. "/terminal-or-claude"))   -- Claude Code; text typed in the launcher becomes the prompt
hl.bind(mod .. " + SPACE",       hl.dsp.exec_cmd("qs ipc call launcher toggle"))   -- Quickshell launcher
hl.bind("XF86Search",               hl.dsp.exec_cmd("qs ipc call launcher toggle"))   -- F4 (magnifier): launcher, like ⌘Space
hl.bind("XF86LaunchA",              hl.dsp.exec_cmd("qs ipc call menu toggle notifications"))   -- F3 (Mission Control, KEY_SCALE): notification centre
hl.bind(mod .. " + XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ; qs ipc call osd mic"), { locked = true })   -- ⌘F5: mic on/off + toast
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(scripts .. "/dictate start"), { locked = true })               -- F5 (sends KEY_MICMUTE): hold -> speech to text (Voxtype, Parakeet)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(scripts .. "/dictate stop"),  { locked = true, release = true })    -- release -> transcribe and type
hl.bind("XF86Fn", hl.dsp.exec_cmd(scripts .. "/dictate fn-down"), { locked = true })                       -- Fn held (over 0.3 s) -> dictation, like F5
hl.bind("XF86Fn", hl.dsp.exec_cmd(scripts .. "/dictate fn-up"),   { locked = true, release = true })
hl.bind(mod .. " + SHIFT + B",   hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + SHIFT + P",   hl.dsp.exec_cmd(scripts .. "/launch-or-focus '^(1[pP]assword|com\\.onepassword\\.OnePassword)$' 1password"))
hl.bind(mod .. " + SHIFT + W",   hl.dsp.exec_cmd(scripts .. "/launch-or-focus '^chrome-web\\.whatsapp\\.com' gtk-launch webapp-whatsapp"))  -- WhatsApp webapp
hl.bind(mod .. " + SHIFT + S",   hl.dsp.exec_cmd(scripts .. "/launch-or-focus '^chrome-app\\.slack\\.com' gtk-launch webapp-slack"))  -- Slack webapp
hl.bind(mod .. " + SHIFT + Y",   hl.dsp.exec_cmd(scripts .. "/launch-or-focus '^chrome-www\\.youtube\\.com' gtk-launch webapp-youtube"))  -- YouTube webapp
hl.bind(mod .. " + SHIFT + I",   hl.dsp.exec_cmd(scripts .. "/launch-or-focus '^(net\\.thunderbird\\.Thunderbird|thunderbird)$' thunderbird"))  -- Email (Thunderbird)
hl.bind(mod .. " + SHIFT + C",   hl.dsp.exec_cmd(scripts .. "/launch-or-focus '^(code|Code)$' code"))  -- VS Code
hl.bind(mod .. " + SHIFT + F",   hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + SHIFT + E",   hl.dsp.exec_cmd("qs ipc call launcher openLevel emoji"))   -- emoji picker
hl.bind(mod .. " + SHIFT + V",   hl.dsp.exec_cmd("qs ipc call launcher openLevel clipboard"))   -- clipboard history
hl.bind(mod .. " + SHIFT + T",   hl.dsp.exec_cmd("qs ipc call shelf toggle"))   -- Shelf: file shelf (dragging to the top edge of the screen also opens it)
hl.bind(mod .. " + ESCAPE",      hl.dsp.exec_cmd("qs ipc call menu toggle notifications"))
hl.bind(mod .. " + CTRL + L",    hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mod .. " + SHIFT + M",   hl.dsp.exec_cmd(scripts .. "/deck-open"))   -- Deck (Spotify)
hl.bind(mod .. " + R",           hl.dsp.exec_cmd(scripts .. "/screenshot clip"))   -- region screenshot to clipboard
hl.bind(mod .. " + SHIFT + R",   hl.dsp.exec_cmd(scripts .. "/screenshot winclip"))   -- window screenshot to clipboard
hl.bind(mod .. " + SHIFT + SPACE", hl.dsp.exec_cmd("qs ipc call menu nav"))   -- top bar via keyboard: ←/→ menu, ↑/↓ row, Enter, Esc
hl.bind(mod .. " + SHIFT + K",     hl.dsp.exec_cmd("kitty --class floating-help -e sh -c 'cat ~/.config/hypr/SHORTCUTS.md ~/.config/hypr/SHORTCUTS.local.md 2>/dev/null | less'"))

-- Universal copy/paste/cut ⌘C/⌘V/⌘X in every app (the Omarchy way)
hl.bind(mod .. " + C", hl.dsp.send_shortcut({ mods = "CTRL",  key = "Insert" }))
hl.bind(mod .. " + V", hl.dsp.send_shortcut({ mods = "SHIFT", key = "Insert" }))
hl.bind(mod .. " + X", hl.dsp.send_shortcut({ mods = "CTRL",  key = "X" }))

-- ⌘⌫ = Delete (move to trash) in the file manager, like in macOS Finder. Elsewhere it messages the launcher:
-- in Settings › Background it removes the selected custom wallpaper (otherwise it does nothing)
hl.bind(mod .. " + BACKSPACE", function ()
    local w = hl.get_active_window()
    if w and (w.class == "org.gnome.Nautilus" or w.class == "nautilus") then
        hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "Delete" }))
    else
        hl.dispatch(hl.dsp.exec_cmd("qs ipc call launcher deleteSelected"))
    end
end)

-- Next/previous tab ⌘⌥← / ⌘⌥→ in every app (Firefox, Chromium, Nautilus, Thunderbird: Ctrl+PageUp/PageDown)
hl.bind(mod .. " + ALT + left",  hl.dsp.send_shortcut({ mods = "CTRL", key = "Prior" }))
hl.bind(mod .. " + ALT + right", hl.dsp.send_shortcut({ mods = "CTRL", key = "Next" }))

-- Windows
hl.bind(mod .. " + W",          hl.dsp.exec_cmd(scripts .. "/close-or-hide"))   -- closes; background apps (hypr/background-apps) are hidden in the background instead
hl.bind(mod .. " + Q",           hl.dsp.window.close())   -- always really closes, background apps too (Deck, WhatsApp…); ⌘W hides them
hl.bind(mod .. " + F",           hl.dsp.window.fullscreen())
-- ⌘T: toggle floating. For Deck: tiled -> floating at its default size, centred; floating but moved/resized ->
-- back to default size, centred; floating already at default position -> tiled. (Size: DECK_SIZE in hyprland.lua)
local DECK_W, DECK_H = DECK_SIZE.w, DECK_SIZE.h
local function xy(t) return t.x or t[1], t.y or t[2] end
local function deck_reset(w)
    hl.dispatch(hl.dsp.window.resize({ x = DECK_W, y = DECK_H, exact = true, window = "address:" .. w.address }))
    hl.dispatch(hl.dsp.window.center({ window = "address:" .. w.address }))
end
local function deck_at_default(w)
    local sw, sh = xy(w.size)
    local x, y = xy(w.at)
    local m = w.monitor
    local cx, cy = (m.width / m.scale - DECK_W) / 2, (m.height / m.scale - DECK_H) / 2
    return sw == DECK_W and sh == DECK_H and math.abs(x - cx) <= 3 and math.abs(y - cy) <= 30   -- y: the bar shifts the centre a little
end
-- A screen-sized floating window (e.g. a lone window floated with ⌘T: geometry stays screen-sized and the border disappears
-- off the left/top) is shrunk to 70 % x 75 % and centred
local function tame_float(w)
    if not (w and w.floating) then return end
    local m = w.monitor
    local mw, mh = m.width / m.scale, m.height / m.scale
    local sw, sh = xy(w.size)
    if sw >= mw * 0.95 and sh >= mh * 0.9 then
        hl.dispatch(hl.dsp.window.resize({ x = math.floor(mw * 0.7), y = math.floor(mh * 0.75), exact = true, window = "address:" .. w.address }))
        hl.dispatch(hl.dsp.window.center({ window = "address:" .. w.address }))
    end
end
local function deck_toggle_float()
    local w = hl.get_active_window()
    if w and w.class == "deck" then
        if not w.floating then
            hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
            deck_reset(w)
        elseif deck_at_default(w) then
            hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
        else
            deck_reset(w)
        end
    else
        hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
        tame_float(hl.get_active_window())
    end
end
hl.bind(mod .. " + T",           deck_toggle_float)

hl.bind(mod .. " + J",           hl.dsp.layout("togglesplit"))

-- Focus with arrows, move window with Shift+arrows
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mod .. " + " .. dir,             hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. dir,     hl.dsp.window.swap({ direction = dir }))
end

-- Workspaces ⌘1–⌘0, move window ⌘⇧1–⌘⇧0
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + TAB",         hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))

-- Scratchpad workspace
hl.bind(mod .. " + S",         hl.dsp.workspace.toggle_special("scratch"))
hl.bind(mod .. " + ALT + S",   hl.dsp.window.move({ workspace = "special:scratch" }))   -- (the Omarchy way; ⌘⇧S is Slack)

-- Mouse: ⌘+drag moves, ⌘+right-drag resizes
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- Media keys (MacBook top row)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 ; wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ ; qs ipc call osd volume"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 ; wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ; qs ipc call osd volume"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ; qs ipc call osd volume"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(scripts .. "/brightness screen up"),   { locked = true, repeating = true })   -- F2: screen brightness in steps of ten
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(scripts .. "/brightness screen down"), { locked = true, repeating = true })   -- F1
hl.bind(mod .. " + XF86MonBrightnessUp",   hl.dsp.exec_cmd(scripts .. "/brightness kbd up"),   { locked = true, repeating = true })   -- ⌘F2: keyboard backlight (steps of ten)
hl.bind(mod .. " + XF86MonBrightnessDown", hl.dsp.exec_cmd(scripts .. "/brightness kbd down"), { locked = true, repeating = true })   -- ⌘F1
hl.bind("XF86Sleep", hl.dsp.exec_cmd(scripts .. "/dnd"), { locked = true })   -- F6 (Apple keyboard sends KEY_SLEEP): do not disturb (mako mode + toast); logind must be set to ignore the key, see config/system/logind-ignore-sleep-key.conf
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl pause"),      { locked = true })   -- always pause, never toggle: Bluetooth headphones send PAUSE when taken off
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(scripts .. "/media-play"), { locked = true })   -- F8: play/pause, or starts Deck if no player is open
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Top bar menu opened by clicking: keys are routed to Quickshell via a submap (no keyboard focus -> a second click on the bar
-- closes the menu normally). Quickshell (shell.qml) enters the submap when the menu opens and resets it when it closes.
-- Safety: Esc always returns to the default map.
local function qsnav(a) return hl.dsp.exec_cmd("qs ipc call menu navkey " .. a) end
hl.define_submap("qsmenu", function ()
    hl.bind("ESCAPE", function ()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.dispatch(qsnav("esc"))
    end)
    hl.bind("LEFT",   qsnav("left"),  { repeating = true })
    hl.bind("RIGHT",  qsnav("right"), { repeating = true })
    hl.bind("UP",     qsnav("up"),    { repeating = true })
    hl.bind("DOWN",   qsnav("down"),  { repeating = true })
    hl.bind("RETURN", qsnav("enter"))
end)
