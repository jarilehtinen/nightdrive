import QtQuick
import QtQuick.Shapes

// A level 0..1 as a ring: a faint full circle and a yellow arc from the bottom, clockwise (Home: a light's brightness).
// At 0 (a light that's off) nothing shows.
// Centre it on an icon; size = the ring's outer diameter.
Item {
    id: r
    property real value: 0
    property real size: 36
    property real thickness: 2
    property color color: Theme.caution
    property real strength: 1          // the arc's opacity (the launcher: fainter off the selected row)
    width: size; height: size

    Shape {
        anchors.fill: parent
        visible: r.value > 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {      // the track
            strokeColor: Qt.rgba(1, 1, 1, 0.1)
            strokeWidth: r.thickness
            fillColor: "transparent"
            PathAngleArc { centerX: r.size / 2; centerY: r.size / 2; radiusX: (r.size - r.thickness) / 2; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
        }
    }
    Shape {
        anchors.fill: parent
        visible: r.value > 0
        opacity: r.strength
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: r.color
            strokeWidth: r.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: r.size / 2; centerY: r.size / 2; radiusX: (r.size - r.thickness) / 2; radiusY: radiusX
                           startAngle: 90; sweepAngle: 360 * Math.min(1, r.value) }
        }
    }
}
