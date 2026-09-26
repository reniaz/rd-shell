import QtQuick
import QtQuick.Controls
import qs.Config

// Reusable auto-hiding scrollbar (idea 12): a thin themed capsule thumb, no
// track, invisible until a scroll or a hover asks for it and gone again
// ~1s after the last of either. Attach it the ordinary Controls way --
// `ScrollBar.vertical: ThinScrollBar {}` inside a Flickable or a ListView
// (Launcher.qml's results list is the first caller).
ScrollBar {
    id: root

    policy: ScrollBar.AsNeeded
    implicitWidth: 6

    // Controls' own definition of "the user is dealing with this right now"
    // -- `active` covers a drag or a wheel-scroll in progress, `hovered`
    // covers sitting over the bar without moving it.
    readonly property bool _busy: root.active || root.hovered

    property bool _visible: false
    opacity: root._visible ? 1 : 0
    visible: root.opacity > 0

    on_BusyChanged: if (root._busy) root._show()
    onPositionChanged: root._show()

    function _show() {
        root._visible = true;
        _idle.restart();
    }

    // ~1s idle per the idea; restarted by every scroll/hover rather than a
    // fixed timeout from first appearance, so staying on the bar keeps it up.
    Timer {
        id: _idle
        interval: 1000
        onTriggered: if (!root._busy) root._visible = false
    }

    Behavior on opacity {
        NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
    }

    // No track: an auto-hiding scrollbar that still draws a permanent rail
    // would defeat the point of hiding it.
    background: null

    contentItem: Rectangle {
        implicitWidth: 6
        // A full capsule on a 6px-wide thumb, well inside the design
        // system's own radius scale (Caelus.radiusChip and up).
        radius: width / 2
        color: Colors.fgDim
        opacity: 0.6
    }
}
