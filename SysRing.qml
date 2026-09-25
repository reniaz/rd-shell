import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Config

// One reading as a ring rather than a bar. The summary strip at the top of
// the system popup is meant to be read in one glance across all three parts
// of the machine, and a ring's fraction reads at that distance where a
// labelled bar would need the label read first -- the bars further down, one
// per tab, are where the detail actually lives.
//
// Same two-arc idea as ClaudeDonutChart's ring (a track drawn full, a value
// arc drawn over it, both via QtQuick.Shapes' PathAngleArc), simplified to one
// wedge instead of a collapsed series: this is a percentage, not a breakdown,
// and it takes its colour from Colors.usage() like the bar pill does, not
// from the chart palette.
Item {
    id: root

    property string label
    // Ignored -- shown as "--" -- while `available` is false, so a card with
    // nothing to report yet (no NVIDIA GPU, no second sample) reads as empty
    // rather than as a fabricated zero.
    property real value: 0
    property bool available: true
    property color fill: Colors.sysColor
    property real size: 56
    property real thickness: 6

    implicitWidth: root.size
    implicitHeight: root.size + labelText.implicitHeight + Caelus.spaceTight

    readonly property real fraction: root.available
        ? Math.max(0, Math.min(100, root.value)) / 100
        : 0

    ColumnLayout {
        anchors.fill: parent
        spacing: Caelus.spaceTight

        Shape {
            id: ring

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: root.size
            implicitHeight: root.size
            preferredRendererType: Shape.CurveRenderer

            readonly property real r: root.size / 2 - root.thickness / 2 - 1

            // The empty track, always drawn full: an unfilled ring reads as a
            // gauge waiting for a value, where an unfilled bar just looks
            // blank. Swept to 359.99 rather than a full circle for the same
            // hairline-seam reason ClaudeDonutChart's own track is.
            ShapePath {
                strokeWidth: root.thickness
                strokeColor: Colors.sysTrack
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    moveToStart: true
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.r
                    radiusY: ring.r
                    startAngle: -90
                    sweepAngle: 359.99
                }
            }

            ShapePath {
                strokeWidth: root.thickness
                fillColor: "transparent"
                strokeColor: root.fill
                capStyle: ShapePath.RoundCap

                Behavior on strokeColor { ColorAnimation { duration: Motion.fast } }

                PathAngleArc {
                    id: valueArc

                    moveToStart: true
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.r
                    radiusY: ring.r
                    startAngle: -90
                    sweepAngle: root.fraction * 359.99

                    // Eased for the same reason SysMeter eases `fraction`
                    // rather than the pixel width it drives: this binding is
                    // live from the moment the popup opens, so an unguarded
                    // Behavior would sweep every ring up from empty on each
                    // open instead of only on the polls that actually move
                    // the reading. A gauge that starts at 0 is a fine place
                    // for a wedge to be seen arriving from, though -- unlike
                    // SysMeter's bars, which sit inside cards already showing
                    // other numbers, this is the very first thing the popup
                    // draws, so there is no "machine booting" impression to
                    // avoid.
                    Behavior on sweepAngle {
                        NumberAnimation { duration: Motion.slow; easing.type: Motion.standard }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.available ? Math.round(root.value) + "%" : "--"
                color: Colors.sysBody
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
            }
        }

        Text {
            id: labelText

            Layout.alignment: Qt.AlignHCenter
            text: root.label
            color: Colors.sysMeta
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel
        }
    }
}
