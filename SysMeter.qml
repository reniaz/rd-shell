import QtQuick
import QtQuick.Layouts
import qs.Config

// A reading and the bar under it. Two lines rather than the Claude panel's
// single row: the values here are pairs -- 12G of 31G, 1.2G of 12G -- and a
// label, a pair and a track do not fit across 330 pixels.
ColumnLayout {
    id: root

    property string label
    property string value
    property real fraction: 0
    property color fill: Colors.sysColor
    property int thickness: 7

    Layout.fillWidth: true
    spacing: 5

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: root.label
            color: Colors.sysTitle
            font.family: "caelusevka"
            font.pixelSize: 14
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            text: root.value
            color: Colors.sysBody
            font.family: "caelusevka"
            font.pixelSize: 13
        }
    }

    Rectangle {
        id: track

        Layout.fillWidth: true
        implicitHeight: root.thickness
        radius: height / 2
        color: Colors.sysTrack

        // Animated so a refresh under the reader's eyes reads as the machine
        // moving rather than as the popup redrawing.
        Rectangle {
            width: Math.round(track.width * Math.max(0, Math.min(1, root.fraction)))
            height: parent.height
            radius: parent.radius
            color: root.fill

            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }
}
