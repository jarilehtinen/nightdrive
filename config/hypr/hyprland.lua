-- Hyprland – Omarchy-style setup for a MacBook (Fedora Asahi)
-- ⌘ = SUPER. Cheat sheet: ~/.config/hypr/SHORTCUTS.md

-----------------
---- MACHINE ----
-----------------
-- Settings for the MacBook's built-in display and a Finnish Mac keyboard. On a PC or a VM, or with another keyboard layout,
-- install.sh writes the machine's own in local.lua (docs/pc.md), which overrides these.
-- MacBook display with the notch, 3024x1964 → scale 2.0 (= 1512x982)
-- (1.75 doesn't divide it evenly; the only clean values are 2.0 and 1.333)
local MONITOR_SCALE = 2.0
local KB_LAYOUT     = "fi"
local KB_VARIANT    = "mac"

local HOME = os.getenv("HOME")

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
-- Autologin (config/greeter/switch.sh autologin) starts this session with NIGHTDRIVE_LOCKED_START=1: the login screen
-- (greeter/lock.qml) locks it first, and nothing else starts until the lock is secure. If the lock isn't up in
-- LOCK_TIMEOUT seconds, the session exits to greetd's login screen rather than stay open.
local LOCK_TIMEOUT = 20
local LOCKED_START = os.getenv("NIGHTDRIVE_LOCKED_START") == "1"
hl.env("NIGHTDRIVE_LOCKED_START", "")   -- not for apps started here (a nested Hyprland would lock itself too)
local RUNTIME = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
-- Flags rather than variables: they survive a config reload, and each step runs once even if the lock is started again
local LOCKED_FLAG   = RUNTIME .. "/nightdrive-session-started"
local UNLOCKED_FLAG = RUNTIME .. "/nightdrive-apps-started"

local function exists(path)
    local f = io.open(path)
    if f then f:close() end
    return f ~= nil
end
-- Under the login screen at an autologin start: before the password (the login apps start with it)
local function session_locked()
    return (LOCKED_START or exists(LOCKED_FLAG)) and not exists(UNLOCKED_FLAG)
end
local update_corners   -- DECORATION below: the screen's rounded corners, off under the login screen
local plugin_starts = {}   -- PLUGINS below: the commands the plugins that are on start with the session (p.start)

local function once(flag)
    local f = io.open(flag)
    if f then f:close(); return false end
    f = io.open(flag, "w")
    if f then f:close() end
    return true
end

-- The session: everything but the login apps. Runs under the lock at an autologin start (lock.qml calls it once secure).
function NightdriveLocked()
    if not once(LOCKED_FLAG) then return end
    -- The keyring daemon that greetd's PAM started gets its secrets and pkcs11 parts (a desktop's login does this): without
    -- them the lock's PAM can't open the login keyring with the password, and an app asking for a secret started a
    -- second daemon that asked for the password again
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11")
    -- graphical-session.target for xdg-desktop-portal (config/systemd/user); restart: fresh environment after a re-login
    hl.exec_cmd("systemctl --user restart nightdrive-session.target")
    -- Theme colours (~/.cache/nightdrive, hypr/scripts/theme) first: Quickshell (the top bar, its menus and the notifications)
    -- reads them on startup
    hl.exec_cmd("sh -c '\"$HOME/.config/hypr/scripts/theme\" apply; exec qs'")
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/wallpaper restore")   -- swaybg with the remembered wallpaper (change: launcher › Settings › Background)
    hl.exec_cmd("env PATH=" .. HOME .. "/.local/bin:" .. os.getenv("PATH") .. " " .. HOME .. "/.local/bin/voxtype-onnx daemon")   -- speech to text (F5), Parakeet
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/idle start")   -- hypridle with the screensaver and screen-off times (launcher › Settings › Screensaver)
    hl.exec_cmd("easyeffects --service-mode -w")   -- headphone EQ in the background (presets: config/easyeffects, picked from the headphone icon in the top bar)
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/bt-audio-follow")   -- Bluetooth headphones become the output when they connect
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/headphones-ctl")   -- Sony / AirPods: listening mode in the headphones menu, AirPods ear detection
    -- reset-failed: the previous session's agent crash-loops after logout (Restart=on-failure) and hits the start limit
    hl.exec_cmd("sh -c 'systemctl --user reset-failed hyprpolkitagent; systemctl --user restart hyprpolkitagent'")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    for _, cmd in ipairs(plugin_starts) do hl.exec_cmd(cmd) end
end

-- The login apps: after the password at an autologin start, as they may ask the keyring (the lock's PAM opens it)
function NightdriveUnlocked()
    if not once(UNLOCKED_FLAG) then return end
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/autostart")   -- the user's login apps (launcher › Settings › Startup; 1Password by default)
    update_corners()
end

hl.on("hyprland.start", function ()
    -- The flags are from an earlier session of this login (the runtime dir lives as long as the user has a session)
    os.remove(LOCKED_FLAG); os.remove(UNLOCKED_FLAG)
    if not LOCKED_START then
        NightdriveLocked(); NightdriveUnlocked()
        return
    end
    local pam = io.open("/etc/pam.d/nightdrive-lock")
    if pam then pam:close() end
    hl.exec_cmd("env NIGHTDRIVE_LOCK_PAM=" .. (pam and "nightdrive-lock" or "login") .. " qs -p " .. HOME .. "/.config/greeter/lock.qml")
    hl.exec_cmd("sh -c 'sleep " .. LOCK_TIMEOUT .. "; [ -e \"" .. LOCKED_FLAG .. "\" ] || hyprctl dispatch \"hl.dsp.exit()\"'")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "kde")  -- Qt apps (Dolphin) use KDE's dark theme
hl.env("MOZ_ENABLE_WAYLAND", "1")
-- NVIDIA's own driver (a PC, install.sh): video decoding and GLX through it (Hyprland wiki › NVIDIA). Checked at start
-- rather than written by install.sh, so a driver added or removed later is followed.
local nvidia = io.open("/proc/driver/nvidia/version")
if nvidia then
    nvidia:close()
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
end

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
        enabled = true,   -- only the workspace slide is on (below); everything else stays instant
    },
})
-- Workspace switch slides like macOS Spaces, so a swipe finishes (or snaps back) smoothly after the fingers lift
hl.curve("spaces", { type = "bezier", points = { {0.25, 1}, {0.5, 1} } })
hl.animation({ leaf = "global",           enabled = false })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 3, bezier = "spaces", style = "slide" })
-- Swapping windows (⌘⇧ + arrows, 4-finger swipe, the drawer) slides them quickly to their new places: the move animation
-- is on only for the swap, so windows otherwise still switch instantly
function NIGHTDRIVE_SWAP(dir, window)
    hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "spaces" })
    hl.dispatch(hl.dsp.window.swap({ direction = dir, window = window }))
    hl.timer(function() hl.animation({ leaf = "windowsMove", enabled = false }) end, { timeout = 220, type = "oneshot" })
end
-- Drawer (⌘D, bindings.lua): slides up from the bottom over the windows, 95 % of the screen high, the rest dimmed
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "spaces", style = "slidevert" })
hl.config({ decoration = { dim_special = 0.6, blur = { special = true } } })   -- dimmed and blurred behind the drawer
local drawerTop = 49    -- 5 % of the screen height, so the drawer is 95 % high
local mon = hl.get_monitors()[1]
if mon then drawerTop = math.floor(mon.height / mon.scale * 0.05) end
hl.workspace_rule({ workspace = "special:drawer", gaps_out = { top = drawerTop, right = 10, bottom = 10, left = 10 } })   -- the same 10 px gaps as other windows

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
        -- A lock that crashed (lock.qml, hyprlock) can be started again from a text console instead of only logging out
        allow_session_lock_restore = true,
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
        mouse_refocus = false,   -- focus follows the mouse only when it crosses into another window (a jittery trackpad no longer steals focus from a new window)
        sensitivity  = 0,
        touchpad = {
            natural_scroll       = false,
            clickfinger_behavior = true,  -- two-finger click = right click
            tap_to_click         = false,  -- like the macOS default: only a physical press clicks
            scroll_factor        = 1.0,   -- libinput's own distance; per-app speeds in scroll.lua
        },
    },
})

-- Three-finger swipe switches workspace
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})
-- A shorter swipe is enough to switch (defaults: half the way, or a fast flick)
hl.config({
    gestures = {
        workspace_swipe_cancel_ratio     = 0.3,    -- switch after 30 % of the way across (default 0.5)
        workspace_swipe_min_speed_to_force = 15,   -- a quick flick switches regardless of distance (default 30)
    },
})
-- Four-finger swipe moves the window in the swipe direction (like ⌘⇧ + arrows)
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.gesture({
        fingers = 4,
        direction = dir,
        action = function() NIGHTDRIVE_SWAP(dir) end,
    })
end
-- Three-finger swipe up shows the drawer, down hides it (like ⌘D). Only toggles when that changes something, so a
-- second swipe the same way doesn't undo the first
local function drawer_gesture(show)
    local special = hl.get_active_special_workspace()
    local open = special ~= nil and special.name == "special:drawer"
    if open ~= show then hl.dispatch(hl.dsp.workspace.toggle_special("drawer")) end
end
hl.gesture({ fingers = 3, direction = "up",   action = function() drawer_gesture(true) end })
hl.gesture({ fingers = 3, direction = "down", action = function() drawer_gesture(false) end })

------------------------
---- KEYBINDINGS → bindings.lua ----
------------------------
require("bindings")
require("scroll")

-----------------------
---- WINDOW RULES ----
-----------------------
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
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
-- Image preview (Files' Space preview Sushi, image viewer Loupe): on top of the windows instead of splitting them, like
-- Quick Look and Preview; ⌘T moves it into the tiling layout
hl.window_rule({
    name  = "float-preview",
    match = { class = "^org\\.gnome\\.Loupe$" },
    float = true,
    size  = "monitor_w*0.85 monitor_h*0.85",
    center = true,
})
-- Sushi sizes itself too small at scale 2 (a GTK3 bug, docs/known-issues.md), so it gets the size too; it briefly
-- flashes a zoomed frame as it opens, until Sushi 51 (GTK4)
hl.window_rule({
    name  = "float-quicklook",
    match = { class = "^org\\.gnome\\.NautilusPreviewer$" },
    float = true,
    size  = "monitor_w*0.85 monitor_h*0.85",
    center = true,
})
hl.window_rule({
    name  = "float-tui",
    match = { class = "^floating-tui$" },
    float = true,
    size  = "700 500",
})
-- Network Connections (Wi-Fi menu › Network settings…): a settings dialog, floating like the TUI it replaced
hl.window_rule({
    name  = "float-network",
    match = { class = "^nm-connection-editor$" },
    float = true,
    size  = "760 520",
})
hl.window_rule({
    name  = "float-help",
    match = { class = "^floating-help$" },
    float = true,
    size  = "900 750",
})
-- 1Password: floating window centred on screen, hidden from screen sharing. Here rather than in plugins/1password: the app
-- may run while the plugin is off (it starts at login), and it must stay out of a shared screen then too.
hl.window_rule({
    name  = "1password",
    match = { class = "^(1[pP]assword|com\\.onepassword\\.OnePassword)$" },
    float = true,
    size  = "1000 700",
    center = true,
    no_screen_share = true,
    suppress_event = "activate activatefocus",   -- must not raise itself (otherwise the special:bg background workspace shows up and covers the windows); ⌘P brings it up
})
-- Telegram: same reason as 1Password, a background app that raises itself (opening it again, links); the launcher and ⌘W handle it
hl.window_rule({
    name  = "telegram",
    match = { class = "^org\\.telegram\\.desktop$" },
    suppress_event = "activate activatefocus",
})

-- Notifications (quickshell/NotificationPopups.qml): what's behind the translucent cards is blurred. ignore_alpha: only
-- where a card is (not the gaps between them or the rounded corners' outside)
-- The bar's menus too (shell.qml): the notification menu is cards like the popups; the other menus are opaque
hl.layer_rule({
    name  = "notifications-blur",
    match = { namespace = "^nightdrive-(notifications|menu)$" },
    blur  = true,
    ignore_alpha = 0.1,
})

-- Thunderbird: slightly translucent (values: active, inactive)
hl.window_rule({
    name  = "thunderbird-opacity",
    match = { class = "^(net\\.thunderbird\\.Thunderbird|thunderbird)$" },
    opacity = "0.97 0.94",
})

-- Rounded corners off when a window is fullscreen (bar hidden), and under the login screen (no bar either)
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
-- Night light (launcher › Settings › Display, hypr/scripts/nightlight): the same shader tints the screen warm, so it stays
-- on under a fullscreen window too (with the corners off). The copies go to ~/.cache/hypr, rewritten only when they change.
local NIGHT_TINT = "vec3(1.0, 0.80, 0.60)"   -- about 4000 K
local function night_on()
    local f = io.open(HOME .. "/.local/state/nightdrive/nightlight")
    local v = f and f:read("l")
    if f then f:close() end
    return v == "on"
end
local night = night_on()
local function night_shader(corners)
    local f = io.open(corner_shader)
    if not f then return "" end
    local src = f:read("a")
    f:close()
    src = src:gsub("const float CORNERS = [%d.]+;", "const float CORNERS = " .. (corners and "1.0" or "0.0") .. ";")
             :gsub("const vec3 WARM = [^;]+;", "const vec3 WARM = " .. NIGHT_TINT .. ";")
    local p = HOME .. "/.cache/hypr/" .. corner_shader:match("([^/]+)%.frag$") .. (corners and "" or "-flat") .. "-night.frag"
    local g = io.open(p)
    local old = g and g:read("a")
    if g then g:close() end
    if old ~= src then
        local w = io.open(p .. ".tmp", "w")      -- the directory: nightlight creates it
        if not w then return "" end
        w:write(src); w:close()
        os.rename(p .. ".tmp", p)                 -- whole, never half-written while Hyprland compiles it
    end
    return p
end
-- `nightdrive preview login` (greeter/lock.qml) hides them too while it shows, as the real login screen does:
-- hyprctl eval "NightdriveCornersHidden(true)"; a config reload brings them back
local corners_hidden = false
function NightdriveCornersHidden(on)
    corners_hidden = on
    update_corners()
end
update_corners = function()
    local ws = hl.get_active_workspace()
    local fullscreen = ws ~= nil and ws.has_fullscreen and ws.fullscreen_mode == 2
    local corners = not fullscreen and not session_locked() and not corners_hidden and not (NIGHTDRIVE and NIGHTDRIVE.corners == false)   -- local.lua can turn the rounding off
    hl.config({ decoration = { screen_shader = night and night_shader(corners) or (corners and corner_shader or "") } })
end
hl.on("window.fullscreen", update_corners)
hl.on("workspace.active",  update_corners)
hl.on("config.reloaded",   update_corners)

-- A background app that raises itself (a notification click, a link) gets focus inside special:bg, and Hyprland shows the
-- whole background workspace over the windows. Bring just that window to the current workspace instead, as its shortcut does.
-- Hyprland first focuses the background workspace's last window and only then the one that asked, so wait a moment and
-- take the window that ends up active. Only while special:bg is shown: after ⌘W hides a window, focus can fall back to a
-- hidden one without showing it.
local raise_pending = false
local function raise_from_background()
    raise_pending = false
    local win = hl.get_active_window()
    local ws = hl.get_active_workspace()
    local special = hl.get_active_special_workspace()
    if not (win and win.workspace and win.workspace.name == "special:bg" and ws
            and special and special.name == "special:bg") then return end
    local target = "address:" .. win.address
    hl.dispatch(hl.dsp.window.move({ workspace = ws.id, follow = false, window = target }))
    hl.dispatch(hl.dsp.workspace.toggle_special("bg"))
    hl.dispatch(hl.dsp.focus({ window = target }))
end
hl.on("window.active", function ()
    local special = hl.get_active_special_workspace()
    if raise_pending or not (special and special.name == "special:bg") then return end
    raise_pending = true
    hl.timer(raise_from_background, { timeout = 50, type = "oneshot" })
end)

-----------------
---- PLUGINS ----
-----------------
-- The plugin folders that are on (plugins/<id>/, ~/.local/share/nightdrive/plugins/<id>/; `nightdrive plugins installed`
-- lists them in plugins.d/active): their hyprland.lua, with window rules and the like. It gets { id, dir, scripts, start }
-- as its ...: start(cmd) runs cmd once when the session starts, with the programs above (NightdriveLocked). One that
-- fails is left out with a line in Hyprland's log. Their keys are in bindings.lua.
do
    local f = io.open(HOME .. "/.cache/nightdrive/plugins.d/active")
    if f then
        for line in f:lines() do
            local id, dir = line:match("^([^\t]+)\t(.+)$")
            local path = dir and dir .. "/hyprland.lua"
            local exists = path and io.open(path)
            if exists then
                exists:close()
                local chunk, err = loadfile(path)
                local ok = chunk and true
                local p = { id = id, dir = dir, scripts = HOME .. "/.config/hypr/scripts",
                            start = function (cmd) table.insert(plugin_starts, cmd) end }
                if chunk then ok, err = pcall(chunk, p) end
                if not ok then print("nightdrive: plugin " .. id .. ": " .. tostring(err)) end
            end
        end
        f:close()
    end
end

-- Per-machine overrides: ~/.config/hypr/local.lua (not in the repo, see .gitignore). `./install.sh --vm` creates it for a virtual machine.
pcall(require, "local")
-- Personal additions from a private overlay: every ~/.config/hypr/local.d/*.lua, in name order (not in the repo, see README)
local extras = io.popen('ls "' .. HOME .. '/.config/hypr/local.d/"*.lua 2>/dev/null')
for f in extras:lines() do dofile(f) end
extras:close()
NIGHTDRIVE_DEFINE_MENU_SUBMAP()   -- bindings.lua: the top bar menu's submap, with every binding above in it
update_corners()
