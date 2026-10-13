-- Hyprland session for the login screen (greetd runs this as user "greetd"). Not used in the normal session.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 2.0 })

hl.config({
    input = { kb_layout = "fi", kb_variant = "mac" },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color = 0xff1a1b26,
    },
    animations = { enabled = false },
})

hl.on("hyprland.start", function ()
    -- Quickshell login screen; once login is done (or the screen closes), this Hyprland exits
    hl.exec_cmd("qs -p /etc/greetd/greeter; hyprctl dispatch 'hl.dsp.exit()'")
end)
