import QtQuick
import QtQuick.Layouts

// The sidebar on the window's left: the app's name (AppTitle) centred in the header's height, what it holds (AppNavRow
// rows, typically) in a column from contentTop down, and a line on its right. Put it first in the window's RowLayout and
// give it a Layout.preferredWidth.
Rectangle {
    id: root
    required property QtObject c
    property string title
    property int headerHeight: 62       // as high as the view's header beside it, so the two titles line up
    property int contentTop: headerHeight + 13
    property int bottomMargin: 18
    property alias spacing: column.spacing
    default property alias content: column.data
    Layout.fillHeight: true
    color: "transparent"
    AppTitle { x: 28; y: (root.headerHeight - height) / 2; c: root.c; text: root.title }
    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.topMargin: root.contentTop
        anchors.bottomMargin: root.bottomMargin
        spacing: 2
    }
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: root.c.divider }
}
