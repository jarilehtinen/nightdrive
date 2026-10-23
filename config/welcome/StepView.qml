import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.kit

// One thing set up by hand, a step at a time: the plugin's steps.md, read by `steps` (its format is there). A step is
// a few plain words, maybe fields to fill in, a command or a file's template with their buttons, and a ✓ once its
// test passes. h opens the README's section beside it (HelpPane), and the window widens for it (shell.qml).
Item {
    id: root
    required property var app
    required property QtObject c
    property string taskId: ""
    property var sheet: null      // `steps ID`: { id, name, icon, steps }
    property int index: 0
    property bool helpShown: false
    property bool copied: false
    // The fields filled in, per task, kept while the window is open: {key} in a command or template becomes its value
    property var kept: ({})
    readonly property var values: kept[taskId] || ({})
    readonly property var steps: sheet ? sheet.steps : []
    readonly property var step: steps[index] || null
    readonly property bool last: index >= steps.length - 1
    // What Enter does on this step: the file to edit, else the command, else its first button; with none, Next
    readonly property string primary: !step ? "" : step.edit ? "edit" : step.code ? "run" : step.actions.length ? "action" : ""
    readonly property string primaryLabel: ({ edit: "Open " + (step ? step.edit : "") + " in the editor",
                                              run: "Run in a terminal",
                                              action: step && step.actions.length ? step.actions[0].label : "" })[primary] || ""
    // The fields this step's command or template still needs, by their labels and steps: until they're filled in, it
    // isn't run with {email} in it
    readonly property var missing: {
        if (!step) return []
        const used = (step.code + " " + step.actions.map(a => a.arg).join(" ")).match(/\{\w+\}/g) || []
        const out = []
        steps.forEach((s, i) => s.asks.forEach(a => {
            if (used.includes("{" + a.key + "}") && !values[a.key]) out.push({ label: a.label, step: i })
        }))
        return out
    }

    onTaskIdChanged: { sheet = null; index = 0; helpShown = false; Qt.callLater(load) }   // once the command has the id
    onIndexChanged: { copied = false; Qt.callLater(focusField, 0) }    // once the step's fields are there
    function load() { if (taskId !== "" && !loader.running) loader.running = true }
    Process {
        id: loader
        command: [root.app.dir + "/steps", root.taskId, JSON.stringify(root.values)]
        stdout: StdioCollector {
            onStreamFinished: {
                const first = root.sheet === null
                try { root.sheet = JSON.parse(text) } catch (e) { return }
                if (first) Qt.callLater(root.focusField, 0)
            }
        }
    }
    // The tests again every few seconds, as the list's are: a step done in the terminal or the browser shows by itself
    Timer { interval: 3000; repeat: true; running: root.visible && root.taskId !== ""; onTriggered: root.load() }
    Timer { id: soon; interval: 1200; onTriggered: root.load() }
    Timer { id: unCopy; interval: 1500; onTriggered: root.copied = false }

    function fill(text) { return text.replace(/\{(\w+)\}/g, (m, k) => values[k] || m) }
    function setValue(k, v) {
        const all = Object.assign({}, kept)
        all[taskId] = Object.assign({}, values)
        all[taskId][k] = v
        kept = all
    }
    function go(i) { index = Math.max(0, Math.min(i, steps.length - 1)) }
    function next() { if (last) app.finishSteps(taskId); else go(index + 1) }
    function act(kind, i) {
        if (missing.length) { go(missing[0].step); return }      // Enter takes you to the field instead
        const v = JSON.stringify(values), n = String(index)
        if (kind === "edit") app.run([app.dir + "/steps", "edit", taskId, n, v])
        else if (kind === "run") app.run([app.dir + "/steps", "run", taskId, n, v])
        else if (kind === "action") app.run([app.dir + "/steps", "action", taskId, n, String(i || 0), v])
        soon.restart()
    }
    function copy() {
        if (!step || !step.code) return
        Quickshell.execDetached(["wl-copy", "--", fill(step.code)])
        copied = true; unCopy.restart()
    }
    // A step's fields take the keyboard as it opens, the first empty one first; Enter goes on, Esc gives it back
    function focusField(i) {
        const f = fields.itemAt(i)
        if (f) f.input.forceActiveFocus(); else app.takeKeys()
    }

    function key(e) {
        const k = e.key
        if (k === Qt.Key_Left) go(index - 1)
        else if (k === Qt.Key_Right) next()
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) { if (primary) act(primary, 0); else next() }
        else if (k === Qt.Key_Y) copy()
        else if (k === Qt.Key_H) helpShown = !helpShown
        else if (k === Qt.Key_Tab) focusField(0)
        else if (k === Qt.Key_PageDown || k === Qt.Key_PageUp) help.page(k === Qt.Key_PageDown ? 1 : -1)
        else if (k === Qt.Key_Escape) app.closeSteps()
        else return false
        return true
    }

    Item {
        id: left
        width: root.helpShown ? root.app.narrow : root.width
        height: parent.height

        // ‹ Mail                Step 2 of 9
        Row {
            id: head
            x: 40; y: 40
            spacing: 8
            HoverHandler { id: back; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.app.closeSteps() }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.g("chevron-left"); font.family: Icons.family; font.pixelSize: 15
                color: back.hovered ? root.c.title : root.c.dim
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.sheet ? root.sheet.name : ""
                color: root.c.text; font.family: root.c.font; font.pixelSize: 13
            }
        }
        Text {
            x: parent.width - width - 40; y: head.y
            text: root.steps.length ? "Step " + (root.index + 1) + " of " + root.steps.length : ""
            color: root.c.faint; font.family: root.c.font; font.pixelSize: 12
        }

        Flickable {
            id: flick
            x: 40; y: head.y + head.height + 24
            width: parent.width - 80
            height: foot.y - y - 16
            clip: true
            contentHeight: body.height
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: body
                width: flick.width
                spacing: 16
                Row {
                    spacing: 12
                    Text {
                        id: stepTitle
                        text: root.step ? root.step.title : ""
                        color: root.c.title; font.family: root.c.font; font.pixelSize: 18; font.weight: Font.DemiBold
                    }
                    Row {
                        visible: root.step !== null && root.step.done === true
                        anchors.verticalCenter: stepTitle.verticalCenter
                        spacing: 6
                        Text { text: Icons.g("check"); font.family: Icons.family; font.pixelSize: 13; color: root.c.primary }
                        Text { text: "Done"; font.family: root.c.font; font.pixelSize: 12; color: root.c.primary }
                    }
                }
                // A Text a paragraph: Qt's Markdown runs them together without a gap
                Column {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: root.step ? root.fill(root.step.text).split(/\n\s*\n/) : []
                        delegate: Text {
                            required property string modelData
                            width: parent.width
                            text: modelData
                            textFormat: Text.MarkdownText
                            wrapMode: Text.Wrap; lineHeight: 1.25
                            color: root.c.body; linkColor: root.c.primary
                            font.family: root.c.font; font.pixelSize: 13
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }
                    }
                }
                Repeater {
                    id: fields
                    model: root.step ? root.step.asks : []
                    delegate: StepField {
                        required property var modelData
                        required property int index
                        width: body.width
                        c: root.c
                        label: modelData.label
                        placeholder: modelData.placeholder
                        value: root.values[modelData.key] || ""
                        onEdited: text => root.setValue(modelData.key, text)
                        onDone: root.focusField(index + 1)
                        onLeave: root.app.takeKeys()
                    }
                }
                // The command or the template, with what's filled in so far; a long template scrolls in its box, so
                // the buttons under it stay in sight
                Rectangle {
                    visible: root.step !== null && root.step.code !== ""
                    width: parent.width
                    height: codeFlick.height + 24
                    radius: 8
                    color: "transparent"; border.color: root.c.line
                    Flickable {
                        id: codeFlick
                        x: 14; y: 12
                        width: parent.width - 28
                        height: Math.min(code.height, 160)
                        clip: true
                        contentHeight: code.height
                        boundsBehavior: Flickable.StopAtBounds
                        Text {
                            id: code
                            width: codeFlick.width
                            text: root.step ? root.fill(root.step.code) : ""
                            wrapMode: Text.WrapAnywhere; lineHeight: 1.2
                            color: root.c.text; font.family: root.c.font; font.pixelSize: 12
                        }
                    }
                }
                Row {
                    spacing: 20
                    AppKeyAction {
                        visible: root.primary !== ""
                        c: root.c
                        keys: "⏎"; label: root.missing.length ? "Fill in " + root.missing[0].label.toLowerCase() + " first"
                                                               : root.primaryLabel
                        color: root.missing.length ? root.c.dim : root.c.primary; hoverColor: root.c.title
                        onClicked: root.act(root.primary, 0)
                    }
                    AppKeyAction {
                        visible: root.step !== null && root.step.code !== ""
                        c: root.c
                        keys: "y"; label: root.copied ? "Copied" : "Copy"
                        onClicked: root.copy()
                    }
                    Repeater {
                        model: root.step ? root.step.actions.slice(root.primary === "action" ? 1 : 0) : []
                        delegate: AppButton {
                            required property var modelData
                            required property int index
                            c: root.c
                            glyph: modelData.kind === "open" ? "external-link" : "terminal"
                            label: modelData.label
                            onClicked: root.act("action", index + (root.primary === "action" ? 1 : 0))
                        }
                    }
                }
            }
        }

        // The keys, for the mouse too
        Item {
            id: foot
            x: 40; y: parent.height - height - 28
            width: parent.width - 80
            height: 22
            Row {
                spacing: 20
                anchors.verticalCenter: parent.verticalCenter
                AppKeyAction {
                    visible: root.index > 0
                    c: root.c; keys: "←"; label: "Back"
                    onClicked: root.go(root.index - 1)
                }
                AppKeyAction {
                    c: root.c; keys: "→"; label: root.last ? "Finish" : "Next"
                    color: root.primary === "" || root.step && root.step.done ? root.c.primary : root.c.dim
                    onClicked: root.next()
                }
                AppKeyAction {
                    c: root.c; keys: "h"; label: root.helpShown ? "Hide help" : "Help"
                    onClicked: root.helpShown = !root.helpShown
                }
            }
            AppKeyAction {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                c: root.c; keys: "esc"; label: "List"
                onClicked: root.app.closeSteps()
            }
        }
    }

    HelpPane {
        id: help
        visible: root.helpShown
        x: left.width
        width: root.width - left.width
        height: parent.height
        c: root.c
        help: root.step ? root.step.help : ({ title: "", markdown: "" })
    }
}
