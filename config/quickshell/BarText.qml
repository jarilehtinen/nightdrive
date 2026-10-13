import QtQuick

// A text in the top bar: the size and y of an adjust.conf row (`element`), vertically centred in its parent by the
// digits' ink (TextMetrics on "0"), not by the font's line height, and snapped to whole device pixels.
Text {
    id: t
    property string element: "text"
    property real dpr: 1
    readonly property var sz: TopBar.size(element)
    font.family: Theme.font
    font.pointSize: sz.size * 0.75   // px -> pt at 96 dpi (pixelSize takes whole pixels only)
    y: Math.round((parent.height / 2 - (baselineOffset + digits.tightBoundingRect.y + digits.tightBoundingRect.height / 2) + sz.y) * dpr) / dpr
    TextMetrics { id: digits; font: t.font; text: "0" }
}
