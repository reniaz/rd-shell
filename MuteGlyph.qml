import QtQuick
import qs.Config

// One glyph, two motions, no instant swap. Unmuted still shows the exact
// glyph it always did -- muting overlays a red diagonal slash rather than
// switching to the icon set's own "_off" variant, for two reasons: a swing
// has to rotate one consistent shape (swapping to a differently-drawn glyph
// mid-rotation would read as a glitch, not a strike) and the icon set's own
// "_off" glyphs already bake in their own mark at their own angle, which
// would fight this one instead of reinforcing it. Every caller keeps its
// own convention for dimming the base glyph's colour on mute (accent ->
// meta, tint -> fgMuted, etc.) -- only the slash is fixed to the shared
// danger token, matugen or not.
//
// Sized off the base glyph alone, with `width`/`height` pinned to it below:
// the slash is pure overlay and the swing is pure rotation, so neither can
// ever nudge the box a caller laid this into. No animation plays before
// `Component.onCompleted` -- a popup opening on an already-muted stream must
// land there, not swing or snap into it.
Item {
    id: root

    property string glyph: "volume_up"
    property bool muted: false
    property color color: Colors.fg
    property color slashColor: Colors.error
    property string fontFamily: Caelus.symbolFamily
    property real size: 16
    // How far the strike kicks the glyph before letting the spring pull it
    // back through rest -- a component constant, not a Motion.qml token:
    // Motion holds durations, easings and spring *pulls*, never a literal
    // distance, and WorkspaceDots' own travel is likewise kept local to it.
    property real swingAngle: 20

    implicitWidth: text.implicitWidth
    implicitHeight: text.implicitHeight
    // Explicit, same reasoning MediaVolume's own root Item gives: something
    // outside a Layout (badge anchors in NotificationBell, mapToItem in
    // MediaVolume) reads `width`/`height` directly and needs them to already
    // equal the implicit size, not merely default to it.
    width: implicitWidth
    height: implicitHeight

    property bool _ready: false
    Component.onCompleted: root._ready = true

    Text {
        id: text

        anchors.centerIn: parent
        text: root.glyph
        color: root.color
        font.family: root.fontFamily
        font.pixelSize: root.size
        rotation: text._swing

        property real _swing: 0

        Behavior on _swing {
            enabled: root._ready
            SpringAnimation {
                spring: Motion.bellSpring
                damping: Motion.bellDamping
                epsilon: Motion.bellSpringEpsilon
            }
        }
        Behavior on color {
            enabled: root._ready
            ColorAnimation { duration: Motion.fast }
        }
    }

    // The strike: kicked to `swingAngle` immediately, then re-aimed at rest
    // a beat later while the spring is still mid-flight -- the same live
    // retarget dotSpring's own comment describes -- so the underdamped
    // spring overshoots back past zero once and rings down, instead of
    // easing straight to a stop the way a single retarget would.
    Timer {
        id: settle
        interval: 45
        onTriggered: text._swing = 0
    }

    onMutedChanged: {
        if (!root._ready) return;
        if (root.muted) {
            settle.stop();
            text._swing = 0;
        } else {
            text._swing = root.swingAngle;
            settle.restart();
        }
    }

    // The slash: a fixed diagonal bar, wide enough to clear the glyph's
    // corners, that only ever tweens scale and opacity -- the angle itself
    // is never part of the animation. OutBack on the way in is what makes it
    // read as snapping into place rather than fading up; the way out is the
    // plain accelerating `exit` curve everything else on this bar leaves
    // through. Wrapped in its own clipped Item, sized exactly to the fixed
    // box above and nothing more -- the overshoot that makes the snap read
    // as a snap also scales this well past full size for an instant, and
    // without a hard edge here that spike paints straight over whatever
    // sits beside this glyph, which is what actually made a pill look like
    // it grew on mute rather than the box itself changing. The swinging
    // glyph above is deliberately outside this clip: a few degrees of
    // rotation spilling past the box for a moment is the swing working as
    // intended, not the bug this clip exists to fix.
    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: slash

            anchors.centerIn: parent
            width: parent.width * 1.6
            height: Math.max(2, root.size * 0.12)
            radius: height / 2
            color: root.slashColor
            rotation: -45
            transformOrigin: Item.Center

            scale: root.muted ? 1 : 0.4
            opacity: root.muted ? 1 : 0

            Behavior on scale {
                enabled: root._ready
                NumberAnimation {
                    duration: Motion.fast
                    easing.type: root.muted ? Motion.enter : Motion.exit
                    easing.overshoot: Motion.enterOvershoot
                }
            }
            Behavior on opacity {
                enabled: root._ready
                NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
            }
        }
    }
}
