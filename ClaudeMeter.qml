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

    spacing: 8

    Rectangle {
        id: track

        Layout.fillWidth: true
        implicitHeight: root.thickness
        radius: height / 2
        color: Colors.claudeTrack

        Rectangle {
            width: track.width * Math.max(0, Math.min(1, root.fraction))
            height: parent.height
            radius: parent.radius
            color: root.fill

            Behavior on width {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    Text {
        text: root.percent + "%"
        color: root.percent > 75 ? root.fill : Colors.claudeMeta
        font.family: "caelusevka"
        font.pixelSize: 13
        visible: root.percent >= 0
    }
}
