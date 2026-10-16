# Files (Nautilus): "Send with LocalSend" in the right-click menu of files and folders (hypr/scripts/localsend send).
# Linked by link.sh to ~/.local/share/nautilus-python/extensions; shown only while the LocalSend plugin is on.
import os
import subprocess

from gi.repository import GObject, Nautilus

HOME = os.path.expanduser("~")
SCRIPT = os.path.join(HOME, ".config/hypr/scripts/localsend")
ENABLED = os.path.join(HOME, ".config/systemd/user/nightdrive-session.target.wants/nightdrive-localsend.service")


class LocalSendMenu(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, files):
        if not os.path.exists(ENABLED):
            return []
        paths = [f.get_location().get_path() for f in files]
        if not paths or None in paths:   # not local files (trash, network)
            return []
        item = Nautilus.MenuItem(name="LocalSend::send", label="Send with LocalSend",
                                 tip="Send to a phone or computer running LocalSend")
        item.connect("activate", lambda *_: subprocess.Popen([SCRIPT, "send", *paths], start_new_session=True))
        return [item]
