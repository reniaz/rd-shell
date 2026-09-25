import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// Track plus fill, with the percentage optionally riding alongside. A RowLayout
// so the label takes its width from the layout and the track simply fills what
// is left -- reading the row's width to size the track would be a binding loop.
RowLayout {
    id: root

    property real fraction: 0

    // -1 drops the inline label entirely, for the places that print the figure
    // in a column of their own.
    property int percent: -1

    property color fill: ClaudeSession.levelColor(root.percent)
    property int thickness: 6

    // On the reading rather than on the fill's width below. The track is sized
    // by the layout, and a layout hands out geometry on its first polish pass --
    // after this component is complete, and so after its Behaviors have started
    // watching. A Behavior on the width would take that first pass for a change
    // and run the bar up from nothing every time the panel is built, which is
    // what made a reopened panel look like a session starting over.
    Behavior on fraction {
        NumberAnimation { duration: Motion.slow; easing.type: Motion.standard }
    }

    spacing: Caelus.space

    Rectangle {
        id: track

        Layout.fillWidth: true
        implicitHeight: root.thickness
        radius: Caelus.radiusPill
        color: Colors.claudeTrack

        Rectangle {
            width: track.width * Math.max(0, Math.min(1, root.fraction))
            height: parent.height
            radius: parent.radius
            color: root.fill

            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
    }

    Text {
        text: root.percent + "%"
        color: root.percent > 75 ? root.fill : Colors.claudeMeta
        font.family: Caelus.fontFamily
        font.pixelSize: Caelus.sizeBody
        visible: root.percent >= 0
    }
}
