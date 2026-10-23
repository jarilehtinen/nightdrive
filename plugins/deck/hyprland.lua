-- Deck's window (plugins/README.md › Hyprland settings): floating on top of everything, centred. ⌘⇧T (the core's
-- bindings.lua) moves it into the tiling layout and back. The terminal Deck (a Deck built before `deck serve`, or `deck`
-- run in a terminal) floats smaller, and ⌘⇧T brings it back to DECK_SIZE.
local DECK_W, DECK_H = 720, 440
local WINDOW_W, WINDOW_H = 1080, 700    -- app/shell.qml's own size
DECK_SIZE = { w = DECK_W, h = DECK_H }
hl.window_rule({
    name  = "float-deck",
    match = { class = "^(sh\\.nightdrive\\.)?deck$" },   -- Ghostty's prefix: hypr/scripts/terminal
    float = true,
    size  = DECK_W .. " " .. DECK_H,
    center = true,
})
hl.window_rule({
    name  = "float-deck-window",
    match = { class = "^org\\.quickshell$", title = "^Deck$" },
    float = true,
    size  = WINDOW_W .. " " .. WINDOW_H,
    center = true,
})
