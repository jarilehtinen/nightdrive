#!/bin/sh
# Prints the apps hidden by fuzzel/sync-apps: path|Name|Icon|Keywords+GenericName
# (DesktopEntries doesn't return NoDisplay apps, so the Launcher reads the override files itself.)
grep -l 'managed by fuzzel/sync-apps' "$HOME"/.local/share/applications/*.desktop 2>/dev/null |
while read -r f; do
  awk -v f="$f" -F= '
    /^\[/ { if (seen) exit; seen = 1; next }
    $1 == "NoDisplay" { nd = tolower($2) }
    $1 == "Name" && !name { name = substr($0, 6) }
    $1 == "Icon" && !icon { icon = substr($0, 6) }
    $1 == "GenericName" && !gen { gen = substr($0, 13) }
    $1 == "Keywords" && !kw { kw = substr($0, 10) }
    END { if (nd == "true" && name != "") print f "|" name "|" icon "|" gen " " kw }
  ' "$f"
done
