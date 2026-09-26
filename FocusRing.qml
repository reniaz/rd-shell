import QtQuick
import qs.Config
import qs.Services

// Idea 9 (Accessibility settings pane): a visible-focus overlay any
// focusable control can drop straight inside itself --
// `FocusRing { anchors.fill: parent; show: someControl.activeFocus }` -- and
// get keyboard-focus visibility for free. It draws over the control's own
// bounds rather than reserving any space of its own, so an instance never
// changes its parent's implicit size or nudges a Layout's spacing: this is
// paint, not layout.
//
// `show` is deliberately the caller's job, not this file's: only the control
// knows what "I am the focused thing right now" means for itself --
// `activeFocus` for a text field or button, a "this row is the selection"
// test for a list item -- so FocusRing never needs to know the difference.
// `Settings.focusRing` is the one thing it does know: the setting gates every
// instance in the shell at once, so turning the toggle off is a single
// property read here, not a sweep of every call site.
Item {
    id: root

    property bool show: false

    // Matches whichever corner radius the parent control already draws at.
    // Left as a property instead of read off the parent directly -- not
    // every parent is a Rectangle with a `radius` to read -- and defaulted to
    // the smallest token in Config/Caelus.qml's shape ladder, the same radius
    // most of the small controls this wraps (toggles, chips, the slider
    // handle) already use.
    property real radius: Caelus.radiusChip

    anchors.fill: parent
    // Above whatever the parent draws, including its own hover/press states,
    // so the ring is never painted under a sibling.
    z: 1000

    visible: Settings.focusRing && root.show

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.radius
        antialiasing: true

        // 2px in a clearly-visible accent, per the a11y brief -- accentBright
        // rather than the popup's ordinary accent, since a focus indicator's
        // one job is to be seen against whatever the control's resting state
        // already is, including against `accent` itself where a control is
        // already wearing it.
        border.width: 2
        border.color: Colors.accentBright
    }
}
