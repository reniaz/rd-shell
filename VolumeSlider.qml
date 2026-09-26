import QtQuick
import QtQuick.Layouts
import qs.Config

// One drag-and-wheel volume row. Extracted out of the media card so the
// output, input and per-app sliders all move volume the same way -- one
// place to get the grab area and the wheel notch right, not three.
RowLayout {
    id: root

    property real value: 0            // 0..1
    property bool muted: false
    // The glyph, shown unchanged whether muted or not -- muting no longer
    // swaps it for an "_off" variant, only overlays MuteGlyph's red slash.
    property string icon: "volume_down"
    property color accent: Colors.popupAccent
    property bool showPercent: true

    signal moved(real value)          // drag/press: absolute 0..1
    signal toggled()                  // mute glyph clicked
    signal stepped(real delta)        // wheel: +0.05 / -0.05, already signed

    // The glyph and the track by name, for a caller that lays its own input
    // over this row (MediaVolume's relative scrub) and has to tell which of
    // the two a click landed on -- by name rather than by child index, so a
    // reordered or added child here can never misroute those clicks.
    readonly property Item iconItem: iconText
    readonly property Item trackItem: track

    spacing: Caelus.space

    MuteGlyph {
        id: iconText

        glyph: root.icon
        muted: root.muted
        color: root.muted ? Colors.audioMeta : root.accent
        size: Caelus.sizeLead

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
            onWheel: wheel => root.stepped(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    Rectangle {
        id: track

        Layout.fillWidth: true
        implicitHeight: 6
        radius: Caelus.radiusPill
        color: Colors.audioTrack

        Rectangle {
            width: Math.round(track.width * root.value)
            height: parent.height
            radius: parent.radius
            color: root.muted ? Colors.audioMeta : root.accent

            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        // Grown vertically only: a six pixel target is not one, and widening
        // it would put the grab point somewhere other than under the cursor.
        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -8
            anchors.bottomMargin: -8
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => root.moved(mouse.x / width)
            onPositionChanged: mouse => {
                if (pressed) root.moved(mouse.x / width);
            }
            onWheel: wheel => root.stepped(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    Text {
        Layout.preferredWidth: 32
        visible: root.showPercent
        text: Math.round(root.value * 100) + "%"
        color: root.muted ? Colors.audioMeta : Colors.audioBody
        font.family: Caelus.fontFamily
        font.pixelSize: Caelus.sizeLabel
        horizontalAlignment: Text.AlignRight

        // The number is small but still worth a wheel target: without this
        // the notch only lands on the icon or the track, leaving a dead
        // strip on the one row that has no slack width to spare.
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onWheel: wheel => root.stepped(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }
}
