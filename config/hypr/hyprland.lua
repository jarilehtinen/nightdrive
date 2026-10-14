-- Hyprland – Omarchy-style setup for a MacBook (Fedora Asahi)
-- ⌘ = SUPER. Cheat sheet: ~/.config/hypr/SHORTCUTS.md

-----------------
---- MACHINE ----
-----------------
-- Settings for the MacBook's built-in display and a Finnish Mac keyboard: the first things to change on other hardware.
-- MacBook display with the notch, 3024x1964 → scale 2.0 (= 1512x982)
-- (1.75 doesn't divide it evenly; the only clean values are 2.0 and 1.333)
local MONITOR_SCALE = 2.0
local KB_LAYOUT     = "fi"
local KB_VARIANT    = "mac"

local HOME = os.getenv("HOME")

-- Deck's floating window size (float-deck rule below; ⌘T in bindings.lua resets the window to it)
DECK_SIZE = { w = 720, h = 440 }

------------------
---- DISPLAY ----
------------------
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = MONITOR_SCALE,
})
-- Scales chosen in the launcher (Settings › Display, hypr/scripts/display): "<output> <scale>" per line.
-- A named output's rule wins over the "" rules above and in local.lua.
local scales = io.open(HOME .. "/.local/state/nightdrive/display")
if scales then
    for line in scales:lines() do
        local output, scale = line:match("^(%S+)%s+([%d.]+)$")
        if output then hl.monitor({ output = output, mode = "preferred", position = "auto", scale = tonumber(scale) }) end
    end
    scales:close()
end

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function ()
    -- graphical-session.target for xdg-desktop-portal (config/systemd/user); restart: fresh environment after a re-login
    hl.exec_cmd("systemctl --user restart nightdrive-session.target")
    -- Theme colours (~/.cache/nightdrive, hypr/scripts/theme) first: Quickshell (the top bar and its menus) and mako read
    -- them on startup. mako runs as its systemd unit: graphical-session.target and D-Bus activation start that unit too,
    -- so a plain `mako &` raced it and left mako.service failed.
    hl.exec_cmd("sh -c '\"$HOME/.config/hypr/scripts/theme\" apply; qs & exec systemctl --user restart mako'")
    hl.exec_cmd("1password", { workspace = "special:bg silent" })   -- 1Password straight to the background without flashing (⌘P brings it up)
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/wallpaper restore")   -- swaybg with the remembered wallpaper (change: launcher › Settings › Background)
    hl.exec_cmd("env PATH=" .. HOME .. "/.local/bin:" .. os.getenv("PATH") .. " " .. HOME .. "/.local/bin/voxtype-onnx daemon")   -- speech to text (F5), Parakeet
    hl.exec_cmd("hypridle")
    hl.exec_cmd("easyeffects --service-mode -w")   -- headphone EQ in the background (presets: config/easyeffects, picked from the headphone icon in the top bar)
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/bt-audio-follow")   -- Bluetooth headphones become the output when they connect
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/headphones-ctl")   -- Sony / AirPods: listening mode in the headphones menu, AirPods ear detection
    -- reset-failed: the previous session's agent crash-loops after logout (Restart=on-failure) and hits the start limit
    hl.exec_cmd("sh -c 'systemctl --user reset-failed hyprpolkitagent; systemctl --user restart hyprpolkitagent'")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "kde")  -- Qt apps (Dolphin) use KDE's dark theme
hl.env("MOZ_ENABLE_WAYLAND", "1")

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border   = "rgba(7aa2f7ff)",       -- Omarchy's Tokyo Night: theme accent
            inactive_border = "rgba(595959aa)",       -- Omarchy default
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 4,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },
        blur = {
            enabled = true,
            size    = 3,
            passes  = 1,
        },
    },
    animations = {
        enabled = false,   -- off on purpose: windows and workspaces switch instantly
    },
})

hl.config({
    dwindle = {
        preserve_split = true,
        force_split    = 2,   -- new windows always open to the right (or below), not on the cursor's side
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        background_color        = 0xff1a1b26,   -- background colour until swaybg draws the wallpaper (softens the flash after login)
        focus_on_activate       = true,   -- apps may request focus: e.g. opening a link → Firefox comes to the front (switches workspace)
    },
})

-----------------------
---- KEYBOARD AND TRACKPAD ----
-----------------------
hl.config({
    input = {
        kb_layout  = KB_LAYOUT,
        kb_variant = KB_VARIANT,
        kb_options = "caps:super",  -- Caps Lock acts as Super
        repeat_rate  = 40,
        repeat_delay = 250,
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll       = false,
            clickfinger_behavior = true,  -- two-finger click = right click
            tap_to_click         = false,  -- like the macOS default: only a physical press clicks
            scroll_factor        = 0.4,
        },
    },
})

-- Three-finger swipe switches workspace
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

------------------------
---- KEYBINDINGS → bindings.lua ----
------------------------
require("bindings")

-----------------------
---- WINDOW RULES ----
-----------------------
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})
-- Slower scrolling for webapps (Chromium app windows): the touchpad scroll_factor (0.4) is global, this multiplies it for these only
hl.window_rule({
    name  = "webapp-scroll",
    match = { class = "^chrome-.*-Default$" },   -- Chromium app windows (webapps)
    scroll_touchpad = 0.7,
    scroll_mouse    = 0.7,
})
hl.window_rule({
    name  = "float-small-tools",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|blueman-manager|nm-connection-editor)$" },
    float = true,
})
-- File picker (Settings › Background › Add new…)
hl.window_rule({
    name  = "float-zenity",
    match = { class = "^(zenity|org.gnome.Zenity)$" },
    float = true,
    size  = "1000 650",
    center = true,
})
hl.window_rule({
    name  = "float-tui",
    match = { class = "^floating-tui$" },
    float = true,
    size  = "700 500",
})
-- Deck: small floating window on top of everything, centred; ⌘T moves it into the tiling layout (and back to floating)
hl.window_rule({
    name  = "float-deck",
    match = { class = "^deck$" },
    float = true,
    size  = DECK_SIZE.w .. " " .. DECK_SIZE.h,
    center = true,
})
hl.window_rule({
    name  = "float-help",
    match = { class = "^floating-help$" },
    float = true,
    size  = "900 750",
})
-- 1Password: floating window centred on screen (bigger than Deck), hidden from screen sharing
hl.window_rule({
    name  = "1password",
    match = { class = "^(1[pP]assword|com\\.onepassword\\.OnePassword)$" },
    float = true,
    size  = "1000 700",
    center = true,
    no_screen_share = true,
    suppress_event = "activate activatefocus",   -- must not raise itself (otherwise the special:bg background workspace shows up and covers the windows); ⌘P brings it up
})

-- Thunderbird: slightly translucent (values: active, inactive)
hl.window_rule({
    name  = "thunderbird-opacity",
    match = { class = "^(net\\.thunderbird\\.Thunderbird|thunderbird)$" },
    opacity = "0.97 0.94",
})

-- Rounded corners off when a window is fullscreen (bar hidden)
-- Top bar opacity (Settings › Top bar opacity, hypr/scripts/bar-style): below 100 % we use a copy of the shader written by
-- the script, in which the top corners are as transparent as the bar. The change is applied with `hyprctl reload`.
local function corner_shader_path()
    local f = io.open(HOME .. "/.local/state/bar-opacity")
    local v = f and tonumber(f:read("l"))
    if f then f:close() end
    if v and v < 100 then
        local p = HOME .. "/.cache/hypr/corners-" .. v .. ".frag"
        local g = io.open(p)
        if g then g:close(); return p end
    end
    return HOME .. "/.config/hypr/shaders/rounded-corners.frag"
end
local corner_shader = corner_shader_path()
local function update_corners()
    local ws = hl.get_active_workspace()
    local fullscreen = ws ~= nil and ws.has_fullscreen and ws.fullscreen_mode == 2
    local corners = not (NIGHTDRIVE and NIGHTDRIVE.corners == false)      -- local.lua can turn the rounding off
    hl.config({ decoration = { screen_shader = (fullscreen or not corners) and "" or corner_shader } })
end
hl.on("window.fullscreen", update_corners)
hl.on("workspace.active",  update_corners)
hl.on("config.reloaded",   update_corners)

-- Per-machine overrides: ~/.config/hypr/local.lua (not in the repo, see .gitignore). `./install.sh --vm` creates it for a virtual machine.
pcall(require, "local")
-- Personal additions from a private overlay: every ~/.config/hypr/local.d/*.lua, in name order (not in the repo, see README)
local extras = io.popen('ls "' .. HOME .. '/.config/hypr/local.d/"*.lua 2>/dev/null')
for f in extras:lines() do dofile(f) end
extras:close()
NIGHTDRIVE_DEFINE_MENU_SUBMAP()   -- bindings.lua: the top bar menu's submap, with every binding above in it
update_corners()
