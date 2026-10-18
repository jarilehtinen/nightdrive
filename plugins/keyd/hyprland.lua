-- Mac Keyboard Shortcuts (plugins/README.md › Hyprland settings): keyd's per-app mapper (app.conf, linked to
-- ~/.config/keyd) follows the active window. install.sh starts it the first time; it needs the keyd group, which a new
-- login brings. Without the plugin, the core's bindings.lua does ⌘⌫ itself.
local p = ...
p.start("keyd-application-mapper -d")
