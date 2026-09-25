import QtQuick
import qs.Config

// A transport control: the bare glyph this bar uses for a button, with a
// hit area wider than the letter it draws. Colour is the whole readout --
// lit while what it names is on, greyed while the player cannot answer it
// yet, as Spotify does with previous at the head of a queue.
//
// Extracted out of MediaPopup.qml -- it used to be an inline `component
// TransportButton` there -- once DesktopMedia.qml needed the same button
// too. The one thing that was popup-specific is now a property instead of
// a literal: see `bottomHitMargin` below.
Text {
    id: button

    property bool active: false
    property bool available: true

    // How far the hit area reaches past the glyph on its bottom edge, on
    // top of the -4 every other edge always gets. The popup's own
    // transport row sits directly above each player's VolumeSlider, whose
    // track grab area (topMargin -8 in VolumeSlider.qml) already reaches up
    // past its own visual top -- leaving this margin at -4 too left a ~1px
    // band where both MouseAreas were hit-testable, and the slider wins it
    // (declared later), turning a click meant for a button into an
    // absolute volume jump. MediaPopup sets this to 0 for that reason; a
    // caller with nothing sitting under its row leaves it at the default.
    property real bottomHitMargin: -4

    signal triggered()

    color: button.active ? Colors.mediaActive
        : point.hovered ? Colors.mediaTitle
        : Colors.mediaMeta
    opacity: button.available ? 1 : 0.35
    font.family: Caelus.symbolFamily
    font.pixelSize: 17

    Behavior on color { ColorAnimation { duration: Motion.fast } }

    MouseArea {
        id: press

        anchors.fill: parent
        anchors.margins: -4
        anchors.bottomMargin: button.bottomHitMargin
        cursorShape: Qt.PointingHandCursor
        // Stays enabled even when the glyph is dim: an `enabled: false`
        // MouseArea does not consume the press at all, so it would fall
        // through to the row-wide `hover` MouseArea behind it and
        // toggle play/pause instead of doing nothing.
        onClicked: {
            if (button.available)
                button.triggered();
        }
    }

    // The glyph's own hover state comes from a handler rather than from
    // `hoverEnabled` on the MouseArea above. A hovering MouseArea is the
    // end of the line for a hover event: the row-wide MouseArea painted
    // beneath this one would lose `containsMouse` the moment the cursor
    // touched a glyph, so the whole card animated out of its hover fill
    // and back again four times as you crossed the transport strip.
    // HoverHandler reports the same thing without swallowing it.
    HoverHandler {
        id: point
    }
}
