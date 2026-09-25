import QtQuick
import QtQuick.Effects
import qs.Config

// A single line that scrolls itself sideways when it doesn't fit, instead
// of eliding -- DesktopMedia.qml's title wants the whole name readable
// eventually, not just its first few words followed by "...". Reusable on
// purpose: any card line that would rather scroll than elide can reach for
// this instead of a plain Text.
//
// Pause at the start, scroll left just far enough to bring the tail into
// view, pause at the end, fade back to the start, repeat -- and only while
// `active` and the text actually overflows its own width. `active` is the
// same idea as MediaArt.qml's own property of that name: the card sets it
// false while collapsed, so nothing is quietly scrolling (or ticking a
// timer) behind a line nobody can see.
Item {
    id: root

    property string text: ""
    property color color: Colors.fg
    property string fontFamily: Caelus.fontFamily
    property int pixelSize: Caelus.sizeLead
    property bool active: true

    implicitHeight: label.implicitHeight

    readonly property bool _overflows: root.width > 0 && label.implicitWidth > root.width
    readonly property bool _scrolling: root.active && root._overflows

    // The 30-40px/s the user asked for, split down the middle: fast enough
    // to read as motion, slow enough that the words stay legible mid-scroll.
    readonly property real _speed: 35
    // 1.5s, matching the pause the user asked for. Not a Motion token: see
    // MediaArtists.qml's own `_holdMs` comment -- this is a steady loop
    // reacting to nothing, not a UI response Motion.qml's tokens are timed
    // for.
    readonly property int _pauseMs: 1500

    // Only the actual overflow needs to be travelled -- once the tail end
    // of the text lines up with the box's own right edge, the whole name
    // has passed through, and there is nothing left to gain by scrolling
    // further.
    readonly property real _overflowPx: Math.max(0, label.implicitWidth - root.width)
    readonly property int _scrollMs: root._speed > 0 ? Math.round(root._overflowPx / root._speed * 1000) : 0

    function _restart() {
        label.x = 0;
        label.opacity = 1;
        cycle.restart();
    }

    function _stop() {
        cycle.stop();
        label.x = 0;
        label.opacity = 1;
    }

    // A track change (or any other text change) always starts the new
    // title from its own beginning, never mid-scroll where the old one
    // happened to be -- even if both titles are long enough to scroll.
    onTextChanged: {
        if (root._scrolling) root._restart();
        else root._stop();
    }

    // Covers both halves of `_scrolling` at once: the card collapsing (and
    // reopening), and this same text starting or stopping needing to
    // overflow as the layout settles.
    on_ScrollingChanged: {
        if (root._scrolling) root._restart();
        else root._stop();
    }

    Component.onCompleted: {
        if (root._scrolling) root._restart();
    }

    // Plain clip, not a gradient-fade mask: a third stacked MultiEffect on
    // top of this card's already layered art and shadows is more risk than
    // a static edge fade is worth -- see MediaArt.qml's own cache:false
    // crash story for why this card treats extra effect layers carefully.
    // A clean edge reads fine at the speed this actually scrolls.
    Item {
        id: viewport

        anchors.fill: parent
        clip: true

        Text {
            id: label

            x: 0
            text: root.text
            color: root.color
            font.family: root.fontFamily
            font.pixelSize: root.pixelSize

            // The same soft shadow every other line on this card uses for
            // legibility over the wallpaper -- see DesktopMedia.qml's own
            // title/artist Text for why this exists.
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowBlur: 0.6
                shadowOpacity: 0.5
                shadowVerticalOffset: 1
            }
        }
    }

    SequentialAnimation {
        id: cycle
        running: false
        loops: Animation.Infinite

        PauseAnimation { duration: root._pauseMs }
        NumberAnimation {
            target: label
            property: "x"
            from: 0
            to: -root._overflowPx
            duration: root._scrollMs
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: root._pauseMs }
        // Fade back to the start rather than snap: a dip through zero
        // opacity around the jump is what the user asked for as the
        // alternative to an instant cut.
        NumberAnimation {
            target: label
            property: "opacity"
            to: 0
            duration: Motion.fast
            easing.type: Motion.exit
        }
        ScriptAction { script: label.x = 0 }
        NumberAnimation {
            target: label
            property: "opacity"
            to: 1
            duration: Motion.fast
            easing.type: Motion.standard
        }
    }
}
