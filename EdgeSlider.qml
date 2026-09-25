import QtQuick
import QtQuick.Layouts
import qs.Config

// One vertical drag control for a single DDC property (brightness or
// contrast) -- VolumeSlider's cousin, but built separately rather than
// taught a second orientation: VolumeSlider belongs to the audio popup and
// this file's whole reason to exist is that the edge panel needs a vertical
// one EDGE can change freely without touching a file it does not own.
//
// DDC read-back trails a drag by hundreds of milliseconds (see S9.md) --
// `ddcutil setvcp` is a few hundred ms of i2c, and the cached value this
// slider is handed only catches up once that round trip completes. Binding
// the fill straight to `value` would have it visibly lag the pointer, or
// snap backwards for a moment right after release while the old cached
// number is still what `value` reports. `_local` is this slider's own
// opinion instead: live for the whole drag, and held a little past release
// until the outside value has actually caught up to it, so the two never
// fight over one pixel.
ColumnLayout {
    id: root

    property real value: 0            // 0..1, authoritative once DDC reports back
    property color accent: Colors.popupAccent
    property string icon: "brightness_6"
    property bool showPercent: true

    signal moved(real value)          // fired on every drag/wheel update, absolute 0..1

    spacing: Caelus.spaceTight

    property real _local: root.value
    property bool _dragging: false
    property bool _holding: false
    readonly property real _shown: (root._dragging || root._holding) ? root._local : root.value

    onValueChanged: {
        if (!root._dragging && !root._holding) root._local = root.value;
        // The read-back this slider was waiting for has arrived: let the
        // bound value back through instead of holding the drag's last word
        // forever.
        if (root._holding && Math.abs(root.value - root._local) < 0.02) root._holding = false;
    }

    function _apply(y) {
        // y=0 is the top of the track (100%); y=track.height is the bottom
        // (0%) -- drag up to raise, the same sense every OS volume/brightness
        // slider already uses.
        const v = Math.max(0, Math.min(1, 1 - y / track.height));
        root._local = v;
        root.moved(v);
    }

    function _release() {
        root._dragging = false;
        root._holding = true;
        holdTimeout.restart();
    }

    function _step(delta) {
        const v = Math.max(0, Math.min(1, root._shown + delta));
        root._local = v;
        root._holding = true;
        holdTimeout.restart();
        root.moved(v);
    }

    // Outlives the drag by enough that a slow DDC round trip has time to
    // land, but not so long that a stuck read leaves the slider parroting a
    // stale number forever -- onValueChanged above is what actually clears
    // this the moment a real update arrives; this is only the backstop.
    Timer {
        id: holdTimeout
        interval: 700
        onTriggered: root._holding = false
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: root.icon
        color: root.accent
        font.family: Caelus.symbolFamily
        font.pixelSize: Caelus.sizeBody
    }

    Rectangle {
        id: track

        Layout.fillHeight: true
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 6
        radius: Caelus.radiusPill
        color: Colors.brightnessTrack

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: Math.round(track.height * root._shown)
            radius: parent.radius
            color: root.accent

            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        // Widened well past the 6px track, the same reasoning VolumeSlider's
        // own grab area gives for growing vertically: a target that thin is
        // not one at all.
        MouseArea {
            anchors.fill: parent
            anchors.leftMargin: -10
            anchors.rightMargin: -10
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => { root._dragging = true; root._apply(mouse.y); }
            onPositionChanged: mouse => { if (pressed) root._apply(mouse.y); }
            onReleased: root._release()
            onCanceled: root._release()
            onWheel: wheel => root._step(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        visible: root.showPercent
        text: Math.round(root._shown * 100) + "%"
        color: Colors.audioBody
        font.family: Caelus.fontFamily
        font.pixelSize: Caelus.sizeLabel
    }
}
