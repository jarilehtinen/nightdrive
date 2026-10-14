# ble.sh (fish-like line editor: history suggestions while typing, syntax colours, completion menu).
# Loaded first without attaching; zz-blesh.sh configures and attaches it after the other files.
# Installed by install.sh into ~/.local/share/blesh; without it bash works as before.
[[ $- == *i* && -f ~/.local/share/blesh/ble.sh ]] && source ~/.local/share/blesh/ble.sh --noattach
