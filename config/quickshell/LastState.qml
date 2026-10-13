pragma Singleton
import QtQuick

// Last known on/off states of the menus. A menu is recreated on every open, so without this the toggle would
// start from its default value and slide to the correct position once the state has been read.
QtObject {
    property bool tailscale: false
    property bool wifi: true
    property bool bluetooth: false
}
