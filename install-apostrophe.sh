#!/bin/bash
# Apostrophe (Markdown viewer and editor, Flathub, per user): the theme, and Markdown files open in it.
set -euo pipefail
repo=$(cd "$(dirname "$0")" && pwd)
id=org.gnome.gitlab.somas.Apostrophe

flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y --noninteractive flathub "$id"
# Its theme is a link into the repo (link.sh), which the sandbox can't see otherwise
flatpak override --user --filesystem="$repo/config/gtk-4.0:ro" "$id"
xdg-mime default "$id.desktop" text/markdown text/x-markdown
"$repo/config/fuzzel/sync-apps" >/dev/null 2>&1 || true
