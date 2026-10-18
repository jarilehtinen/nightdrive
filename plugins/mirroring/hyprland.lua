-- Screen Mirroring (plugins/README.md › Hyprland settings): doubletake's daemon finds the AirPlay receivers for the
-- display menu and Settings › Display › Screen Mirroring. Started with the session; install.sh builds it.
local p = ...
p.start("sh -c '[ -x \"$HOME/.local/bin/doubletake\" ] && exec \"$HOME/.local/bin/doubletake\" -daemonize'")
