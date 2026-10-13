import QtQuick

// Three dots in the theme colour that pulse one after another: something is in progress (MenuRow's busy).
Row {
    id: dots
    spacing: 3
    Repeater {
        model: 3
        Rectangle {
            required property int index
            width: 5; height: 5; radius: 2.5
            color: Theme.primary
            opacity: 0.25
            // Every dot's cycle is equally long (960 ms), so the stagger stays in step
            SequentialAnimation on opacity {
                running: dots.visible
                loops: Animation.Infinite
                PauseAnimation { duration: index * 160 }
                NumberAnimation { to: 1; duration: 320; easing.type: Easing.OutQuad }
                NumberAnimation { to: 0.25; duration: 320; easing.type: Easing.InQuad }
                PauseAnimation { duration: (2 - index) * 160 }
            }
        }
    }
}
