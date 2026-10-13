# eza replaces ls (install: sudo dnf install eza). The aliases are only active if eza is found.
# Icons come from the Symbols Nerd Font fallback (bundled with kitty); colours follow the terminal palette.
if command -v eza >/dev/null 2>&1; then
  export EZA_ICON_SPACING=2       # gap between icon and name (wide Nerd Font icons cover a single space)
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -l --icons --group-directories-first --git'          # long list + git status
  alias la='eza -la --icons --group-directories-first --git'         # hidden files too
  alias lt='eza --tree --level=2 --icons --group-directories-first'  # tree view (2 levels); e.g. lt -L3 or lt -a
fi
