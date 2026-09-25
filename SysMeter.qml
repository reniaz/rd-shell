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

    // The movement is animated here, on the reading, and not down on the width
    // of the bar drawn from it. A Behavior on that width would also catch the
    // width the layout hands the track, and a layout only hands out geometry on
    // its first polish pass -- which happens after this component is complete
    // and its Behaviors are therefore live. Every meter would read that first
    // pass as a change and sweep up out of nothing, so a popup rebuilt on each
    // open would show the machine booting rather than the machine being looked
    // at again. Animating the fraction instead leaves the opening frame exact
    // and keeps the easing for the refreshes that genuinely move it.
    Behavior on fraction {
        NumberAnimation { duration: Motion.slow; easing.type: Motion.standard }
    }

    Layout.fillWidth: true
    spacing: 5

    RowLayout {
        Layout.fillWidth: true
        spacing: Caelus.space

        Text {
            text: root.label
            color: Colors.sysTitle
            font.family: Caelus.fontFamily
            font.pixelSize: 14
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            text: root.value
            color: Colors.sysBody
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeBody
        }
    }

    Rectangle {
        id: track

        Layout.fillWidth: true
        implicitHeight: root.thickness
        radius: Caelus.radiusPill
        color: Colors.sysTrack

        // Follows the track exactly and instantly: the easing that makes a
        // refresh read as the machine moving rather than as the popup
        // redrawing lives on `fraction` above.
        Rectangle {
            width: Math.round(track.width * Math.max(0, Math.min(1, root.fraction)))
            height: parent.height
            radius: parent.radius
            color: root.fill

            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
    }
}
