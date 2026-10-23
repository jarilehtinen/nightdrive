import QtQuick
import QtQuick.Layouts
import qs

// A search line: the search glyph and a field with a quiet placeholder. It is a focus scope, so forceActiveFocus() puts the
// cursor in the field. Return, ↓ and Esc are the app's to decide: they come out as signals.
FocusScope {
    id: root
    required property QtObject c
    property string placeholder: "Search"
    property alias text: input.text
    property int pixelSize: 14
    signal edited()
    signal returnPressed()
    signal downPressed()
    signal escapePressed()
    implicitHeight: 30
    RowLayout {
        anchors.fill: parent
        spacing: 10
        Text { text: Icons.g("search"); font.family: Icons.family; font.pixelSize: 15; color: root.c.faint }
        TextInput {
            id: input
            Layout.fillWidth: true
            focus: true
            color: root.c.text; font.family: root.c.font; font.pixelSize: root.pixelSize
            selectionColor: root.c.sel
            Text {
                visible: !input.text
                text: root.placeholder; color: root.c.faint; font: input.font
            }
            onTextEdited: root.edited()
            Keys.onReturnPressed: root.returnPressed()
            Keys.onDownPressed: root.downPressed()
            Keys.onEscapePressed: root.escapePressed()
        }
    }
}
