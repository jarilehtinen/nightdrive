-----------------------
---- SCROLLING ----
-----------------------
-- Every app's scroll speed in one place. The touchpad's scroll_factor is 1.0 (hyprland.lua), so an app gets libinput's
-- own distance: GTK moves the content about as far as the fingers, like macOS. Apps that turn it into a different
-- distance get a multiplier here (window rule: touchpad, mouse wheel). 1.0 = as libinput sends it.
-- Not windows, set in their own config: Quickshell (TouchScroll.qml, NotificationCard.qml: touchScale 0.8).
-- kitty uses its default touch_scroll_multiplier (1.0).
local apps = {
    -- Firefox: the reference speed (fling momentum in firefox/user.js)
    { name = "firefox",  class = "^(org.mozilla.firefox|firefox)$",                   touchpad = 0.45, mouse = 1.0 },
    -- Chromium browser and app windows (webapps): moves further per scroll event than Firefox
    { name = "chromium", class = "^(chromium|chromium-browser|chrome-.*-Default)$", touchpad = 0.2, mouse = 0.5 },
}

for _, a in ipairs(apps) do
    hl.window_rule({
        name  = "scroll-" .. a.name,
        match = { class = a.class },
        scroll_touchpad = a.touchpad,
        scroll_mouse    = a.mouse,
    })
end
