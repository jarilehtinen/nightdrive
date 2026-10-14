# History: large, without duplicates, and shared between terminals. Without histappend every closing window
# overwrote the file with its own list; history -a writes each command right away so a new window sees it.
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups   # ignoreboth: no duplicates in a row, a leading space keeps a command out of history
HISTIGNORE='ls:ll:la:exit:clear'
shopt -s histappend cmdhist
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}history -a"

# fzf: Ctrl+R searches history, Ctrl+T picks a file, Alt+C changes directory (ble.sh loads its own version in zz-blesh.sh)
if [[ $- == *i* && ! ${BLE_VERSION-} ]] && command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash)"
fi
