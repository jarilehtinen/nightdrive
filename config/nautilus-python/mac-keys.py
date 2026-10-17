# Files (Nautilus) with Finder's keys, part of the Mac Keyboard Shortcuts plugin (install-keyd.sh): Enter renames the
# selection, ⌘O opens it (F2 still renames too). Linked by link.sh to ~/.local/share/nautilus-python/extensions; works
# only while the plugin is on.
# Nautilus has no extension API for keys: a capture-phase key controller on each Files window catches the keys before
# the file view does, and only when the focus is in the file view (not in a text field, the rename popover or the
# sidebar). It runs the view's own actions (view.rename, view.open-with-default-application); if a Nautilus update
# renames them, the keys just do what they did before.
import os

from gi.repository import Gdk, GLib, GObject, Gtk, Nautilus

ENABLED = "/etc/systemd/system/multi-user.target.wants/keyd.service"   # the plugin's test: systemctl is-enabled keyd
ENTER = {Gdk.KEY_Return, Gdk.KEY_KP_Enter, Gdk.KEY_ISO_Enter}
MODS = Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.ALT_MASK | Gdk.ModifierType.SUPER_MASK


def file_view(widget):
    """The NautilusFilesView the focused widget is in, or None (text field, popover, sidebar, path bar)."""
    if isinstance(widget, Gtk.Editable):
        return None
    while widget is not None:
        if isinstance(widget, Gtk.Popover):
            return None
        if GObject.type_name(widget) == "NautilusFilesView":
            return widget
        widget = widget.get_parent()
    return None


def on_key(controller, keyval, keycode, state):
    mods = state & MODS
    if mods == 0 and keyval in ENTER:
        action = "view.rename"
    elif mods == Gdk.ModifierType.SUPER_MASK and keyval in (Gdk.KEY_o, Gdk.KEY_O):
        action = "view.open-with-default-application"
    else:
        return False
    if not os.path.exists(ENABLED):
        return False
    view = file_view(controller.get_widget().get_focus())
    return view is not None and view.activate_action(action, None)


def watch(window):
    if GObject.type_name(window) != "NautilusWindow" or getattr(window, "_mac_keys", False):
        return
    window._mac_keys = True
    keys = Gtk.EventControllerKey()
    keys.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
    keys.connect("key-pressed", on_key)
    window.add_controller(keys)


def watch_all(*_):
    for window in Gtk.Window.list_toplevels():
        watch(window)


class MacKeys(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        super().__init__()
        Gtk.Window.get_toplevels().connect("items-changed", watch_all)
        GLib.idle_add(watch_all)
