# Files (Nautilus): "Send with LocalSend" in the right-click menu of files and folders (bin/localsend send).
# Linked by link.sh to ~/.local/share/nautilus-python/extensions; shown only while the LocalSend plugin is installed and on
# (its receiver enabled, and not turned off with `nightdrive plugins off localsend`).
import os
import subprocess

from gi.repository import GObject, Nautilus

HOME = os.path.expanduser("~")
SCRIPT = os.path.join(HOME, ".local/bin/localsend")
ENABLED = os.path.join(HOME, ".config/systemd/user/nightdrive-session.target.wants/nightdrive-localsend.service")
OFF = os.path.join(HOME, ".local/state/nightdrive/plugins-off/localsend")


class LocalSendMenu(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, files):
        if not os.path.exists(ENABLED) or os.path.exists(OFF):
            return []
        paths = [f.get_location().get_path() for f in files]
        if not paths or None in paths:   # not local files (trash, network)
            return []
        item = Nautilus.MenuItem(name="LocalSend::send", label="Send with LocalSend",
                                 tip="Send to a phone or computer running LocalSend")
        item.connect("activate", lambda *_: subprocess.Popen([SCRIPT, "send", *paths], start_new_session=True))
        return [item]
