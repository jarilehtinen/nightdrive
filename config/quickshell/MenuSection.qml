import QtQuick

// A section title inside a menu (e.g. "MACHINES"): capitals in the theme colour, smaller than the menu's own header;
// the same size as the titles written out in SystemMenu and WifiMenu ("TEMPERATURES", "NETWORKS").
Text {
    property string title: ""
    width: parent ? parent.width : 0
    topPadding: 6
    text: title.toUpperCase()
    color: Theme.primary
    font { family: Theme.font; pixelSize: 11; letterSpacing: 0.6 }
}
