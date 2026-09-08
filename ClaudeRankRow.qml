import QtQuick
import QtQuick.Layouts
import qs.Config

// A labelled proportional bar: the workhorse behind every "top N" list in the
// panel. ClaudeStatRow prints a label and a figure; this adds the one thing a
// ranking needs that a table cannot show, which is how far apart the entries
// are. ClaudeMeter is deliberately not reused -- it carries a percentage label
// and a severity colour, and neither means anything when the quantity being
// drawn is a share of spend.
ColumnLayout {
    id: root

    property string label
    property string value
    property real fraction: 0

    // A second, dim line under the label for the context a ranking usually
    // needs: how many sessions a project holds, which model a session ran.
    // Empty by default, and the row loses the height entirely when it is.
    property string sublabel

    property color fill: Colors.claudeAccent
    property int thickness: 4

    Layout.fillWidth: true
    spacing: 3

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: root.label
            color: Colors.claudeBody
            font.family: "caelusevka"
            font.pixelSize: 13
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            text: root.value
            color: Colors.claudeTitle
            font.family: "caelusevka"
            font.pixelSize: 13
        }
    }

    Text {
        text: root.sublabel
        color: Colors.claudeMeta
        font.family: "caelusevka"
        font.pixelSize: 13
        elide: Text.ElideRight
        visible: root.sublabel !== ""
        Layout.fillWidth: true
    }

    Rectangle {
        id: track

        Layout.fillWidth: true
        Layout.topMargin: 1
        implicitHeight: root.thickness
        radius: height / 2
        color: Colors.claudeTrack

        Rectangle {
            // Clamped rather than trusted: `fraction` is arithmetic on a
            // payload that can be empty, and a bar wider than its track paints
            // outside the card.
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
}
