-- Deck's window (plugins/README.md › Hyprland settings): small, floating on top of everything, centred. ⌘⇧T (the core's
-- bindings.lua) moves it into the tiling layout and back to floating at DECK_SIZE.
local DECK_W, DECK_H = 720, 440
DECK_SIZE = { w = DECK_W, h = DECK_H }
hl.window_rule({
    name  = "float-deck",
    match = { class = "^(sh\\.nightdrive\\.)?deck$" },   -- Ghostty's prefix: hypr/scripts/terminal
    float = true,
    size  = DECK_W .. " " .. DECK_H,
    center = true,
})
