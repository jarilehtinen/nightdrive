# Simple prompt: directory in green + ❯ (red if the previous command failed).
# Replaces Fedora's default (user@host:path$). Sourced from ~/.bashrc.d/.
PROMPT_DIRTRIM=2          # long paths are shortened to ~/…/Projects/myapp

__set_prompt() {
  local ec=$?
  # ANSI 32 / 31 = the terminal palette's green and red (kitty: Tokyo Night #9ece6a / #f7768e)
  local green=$'\[\e[32m\]' red=$'\[\e[31m\]' reset=$'\[\e[0m\]'
  local mark=$green
  (( ec != 0 )) && mark=$red
  PS1="${green}\w${reset} ${mark}❯${reset} "
}
# Run first so $? is still the previous command's status; Fedora's window-title command stays in effect
PROMPT_COMMAND="__set_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
