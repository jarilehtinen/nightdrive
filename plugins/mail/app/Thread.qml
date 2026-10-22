import QtQuick

// The open thread: its subject, then each message with its attachments. Mail's reading pane, and a message window's.
Flickable {
    id: root
    // From the window it is in: the look, notmuch, and Mail's helpers (name, fullDate, rich, openPart …).
    required property QtObject c
    required property QtObject nm
    required property var app
    property var messages: []
    property int htmlMode: 0            // 0 text, 1 HTML on the dark page, 2 HTML on light paper
    signal cycleHtml()
    signal resumeDraft()
    // Light paper for HTML as sent: senders pick their colours for a white page, whatever the desktop's theme
    readonly property color paperBg: "#f4f1f6"
    readonly property color paperText: "#1d1a21"
    readonly property color paperSelection: "#d9c6e6"
    clip: true
    contentHeight: page.implicitHeight + 96
    boundsBehavior: Flickable.StopAtBounds
    TouchScroll { view: root }
    // Plain text first; the HTML version is a press away when the message has one.
    Rectangle {
        visible: root.messages.some(m => m.html !== "")
        x: page.x + page.width - width + 12
        y: 12
        implicitWidth: viewRow.implicitWidth + 24
        implicitHeight: 30
        radius: 8
        color: vh.hovered ? c.hover : "transparent"
        HoverHandler { id: vh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.cycleHtml() }
        Row {
            id: viewRow
            anchors.centerIn: parent
            spacing: 8
            KeyCap { anchors.verticalCenter: parent.verticalCenter; c: root.c; keys: "h"; tint: c.faint }
            Text { anchors.verticalCenter: parent.verticalCenter; text: ["Text", "HTML, dark", "HTML as sent"][root.htmlMode]; color: c.dim; font.family: c.font; font.pixelSize: 12 }
        }
    }
    Column {
        id: page
        width: Math.max(240, Math.min(640, root.width - 80))
        x: Math.max(24, (root.width - width) / 2)
        y: 48
        spacing: 32
        Text {
            width: parent.width
            visible: root.messages.length > 0
            text: root.messages.length ? root.messages[0].subject : ""
            wrapMode: Text.Wrap
            font.family: c.font; font.pixelSize: 22; font.weight: Font.Medium; font.letterSpacing: -0.2
            lineHeight: 1.1
            color: c.title
        }
        Repeater {
            model: root.messages
            delegate: Column {
                id: msgCol
                required property var modelData
                width: page.width
                spacing: 28
                Item {
                    id: head
                    // In a narrow pane the date goes under the address instead of beside the name.
                    readonly property bool wide: width >= 520
                    width: parent.width; height: hdr.implicitHeight + 28
                    Column {
                        id: hdr
                        width: parent.width
                        spacing: 4
                        Item {
                            width: parent.width; height: sender.implicitHeight
                            Text {
                                id: sender
                                anchors.left: parent.left
                                anchors.right: head.wide ? sideDate.left : parent.right
                                anchors.rightMargin: head.wide ? 24 : 0
                                elide: Text.ElideRight
                                text: app.name(modelData.from); color: c.accent; font.family: c.font; font.pixelSize: 13
                            }
                            Text {
                                id: sideDate
                                visible: head.wide
                                anchors.right: parent.right; anchors.baseline: sender.baseline
                                text: app.fullDate(modelData.timestamp); color: c.faint; font.family: c.font; font.pixelSize: 12
                            }
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: app.address(modelData.from); color: c.faint; font.family: c.font; font.pixelSize: 12
                        }
                        Text {
                            visible: !head.wide
                            text: app.fullDate(modelData.timestamp); color: c.faint; font.family: c.font; font.pixelSize: 12
                        }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: c.line }
                }
                TextEdit {
                    visible: !(root.htmlMode > 0 && modelData.html)
                    width: parent.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.RichText
                    text: visible ? app.rich(modelData.body) : ""
                    font.family: c.font; font.pixelSize: 14
                    color: c.body
                    selectionColor: c.sel
                    onLinkActivated: link => Qt.openUrlExternally(link)
                    HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor }
                }
                // The HTML version: on the dark page with the sender's colours taken out, or on light paper as sent
                // (senders pick their colours for a white page).
                Rectangle {
                    readonly property bool paper: root.htmlMode === 2
                    visible: root.htmlMode > 0 && modelData.html !== ""
                    width: parent.width
                    height: visible ? html.implicitHeight + (paper ? 48 : 0) : 0
                    radius: 10
                    color: paper ? root.paperBg : "transparent"
                    TextEdit {
                        id: html
                        x: parent.paper ? 24 : 0; y: x
                        width: parent.width - 2 * x
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.RichText
                        text: !parent.visible ? "" : parent.paper ? modelData.html : nm.darken(modelData.html, c.accent)
                        font.pixelSize: 14
                        color: parent.paper ? root.paperText : c.body
                        selectionColor: parent.paper ? root.paperSelection : c.sel
                        onLinkActivated: link => Qt.openUrlExternally(link)
                        HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor }
                    }
                }
                // Attachments: a click opens one, "Save" puts it in the downloads folder.
                Flow {
                    width: parent.width
                    visible: modelData.files.length > 0
                    spacing: 8
                    Repeater {
                        model: modelData.files
                        delegate: Rectangle {
                            id: file
                            required property var modelData
                            readonly property var msg: msgCol.modelData
                            implicitWidth: fileRow.implicitWidth + 28
                            implicitHeight: 34
                            radius: 8
                            border.color: c.line
                            color: fileHover.hovered ? c.hover : "transparent"
                            HoverHandler { id: fileHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: app.openPart(file.msg, file.modelData) }
                            Row {
                                id: fileRow
                                anchors.centerIn: parent
                                spacing: 10
                                Text {
                                    id: fileName
                                    text: file.modelData.name; color: c.text; font.family: c.font; font.pixelSize: 12
                                    width: Math.min(implicitWidth, 280); elide: Text.ElideMiddle
                                }
                                Text { text: app.size(file.modelData.size); color: c.faint; font.family: c.font; font.pixelSize: 11; anchors.baseline: fileName.baseline }
                                Text {
                                    text: "Save"; font.family: c.font; font.pixelSize: 11; anchors.baseline: fileName.baseline
                                    color: saveHover.hovered ? c.accent : c.dim
                                    opacity: fileHover.hovered ? 1 : 0
                                    HoverHandler { id: saveHover }
                                    TapHandler { onTapped: app.savePart(file.msg, file.modelData) }
                                }
                            }
                        }
                    }
                }
                // A draft is written on in the writing window.
                Rectangle {
                    visible: modelData.draft
                    implicitWidth: draftRow.implicitWidth + 28
                    implicitHeight: 34
                    radius: 8
                    color: draftHover.hovered ? c.hover : "transparent"
                    border.color: c.line
                    HoverHandler { id: draftHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.resumeDraft() }
                    Row {
                        id: draftRow
                        anchors.centerIn: parent
                        spacing: 8
                        KeyCap { anchors.verticalCenter: parent.verticalCenter; c: root.c; keys: "⏎"; tint: c.faint }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Continue writing"; color: c.accent; font.family: c.font; font.pixelSize: 12 }
                    }
                }
                Item { width: 1; height: 24 }
            }
        }
    }
    Text {
        visible: root.messages.length === 0
        anchors.centerIn: parent
        text: "No message selected"; color: c.faint; font.family: c.font; font.pixelSize: 12
    }
}
