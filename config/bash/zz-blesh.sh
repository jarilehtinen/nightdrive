# Configures and attaches ble.sh (loaded by 00-blesh.sh); runs last, after the prompt and history settings.
if [[ ${BLE_VERSION-} ]]; then
  ble-face auto_complete=fg=8                 # the suggestion in the terminal palette's dim grey (default: grey background)
  bleopt exec_errexit_mark=                   # the prompt already turns red on an error, no "[ble: exit 1]" line
  # ↑/↓ search history for lines starting with what is typed; on an empty line they step through history as usual
  ble-bind -m emacs -f up   'history-search-backward hide-status:immediate-accept:empty=emulate-readline:point=end'
  ble-bind -m emacs -f down 'history-search-forward hide-status:immediate-accept:empty=emulate-readline:point=end'
  command -v fzf >/dev/null 2>&1 && ble-import -d integration/fzf-key-bindings   # Ctrl+R, Ctrl+T, Alt+C
  ble-attach
fi
