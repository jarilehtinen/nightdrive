import QtQuick
import qs

// Beside a step done by hand (h in StepView): the README's section that the step's steps.md names, the whole of it,
// for when the plain-words step isn't enough. Read from the file, so it works offline.
Item {
    id: root
    required property QtObject c
    property var help: ({ title: "", markdown: "" })

    // PgUp / PgDn from StepView's keys: the pane never takes the keyboard
    function page(dir) {
        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + dir * flick.height * 0.85))
    }
    onHelpChanged: flick.contentY = 0

    Rectangle { width: 1; height: parent.height; color: root.c.divider }

    Text {
        id: title
        x: 32; y: 40
        width: parent.width - 64
        text: root.help.title || "Help"
        elide: Text.ElideRight
        color: root.c.title; font.family: root.c.font; font.pixelSize: 15; font.weight: Font.Medium
    }

    Flickable {
        id: flick
        x: 32; y: title.y + title.height + 16
        width: parent.width - 52
        height: parent.height - y - 28
        clip: true
        contentHeight: body.height + 16
        boundsBehavior: Flickable.StopAtBounds
        Text {
            id: body
            width: flick.width - 12
            text: root.help.markdown || "This step has no help of its own."
            textFormat: Text.MarkdownText
            wrapMode: Text.Wrap; lineHeight: 1.2
            color: root.c.body; linkColor: root.c.primary
            font.family: root.c.font; font.pixelSize: 12
            onLinkActivated: link => Qt.openUrlExternally(link)
        }
    }
}
