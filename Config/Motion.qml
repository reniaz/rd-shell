pragma Singleton
import Quickshell
import QtQuick

// Every duration and easing the shell animates with. Before this existed the
// same four numbers were retyped at 72 call sites -- `duration: 120` alone
// appeared 42 times -- so retiming anything meant a grep and a held breath.
//
// The names say what the motion is for, not how long it takes. Pick by role
// and the timing stays coherent across popups, pills, dots and toasts even
// when a value here changes later.
Singleton {
    id: root

    // ── durations, milliseconds ──────────────────────────────
    // A hover, a colour swap, a few pixels of travel. The default: if a
    // motion has no reason to be slower, it is this one.
    readonly property int fast: 120
    // A shape changing size in place -- a dot stretching into a capsule, a
    // popup unfolding out of its pill.
    readonly property int base: 170
    // Something crossing the screen edge: a toast sliding in, a card leaving.
    // PopupLoader's hold is pinned to this too, since it exists to outlive
    // exactly this animation -- see PopupLoader.qml. BarPopup's settle timer
    // used to share that pin as well, but no longer does: it now reads its
    // own interval straight off the reveal animation's `duration` (which is
    // `spatial`, below) instead, so the two cannot drift apart even if the
    // entrance's own timing changes again.
    readonly property int slow: 220
    // The wallpaper swap only. Deliberately far slower than anything else --
    // it is a full-screen circular reveal and reads as a scene change, not as
    // UI feedback.
    readonly property int reveal: 700
    // A panel coming out of the bar. Material 3 Expressive's default spatial
    // duration, the one caelestia opens every one of its panels on. Long next
    // to everything above it on purpose: a card that extrudes has a distance
    // to cover, and at `base` speed it only blinks into place. Pair it with
    // `spatialCurve` below and not with `standard` -- half a second of plain
    // OutCubic is what actually reads slow.
    readonly property int spatial: 500

    // ── easings ──────────────────────────────────────────────
    // Decelerating. Almost everything: it starts at full speed, so short
    // durations still feel immediate.
    readonly property int standard: Easing.OutCubic
    // Overshoots and settles back. For something appearing from nothing.
    readonly property int enter: Easing.OutBack
    readonly property real enterOvershoot: 0.7
    // Accelerating. For something leaving, where the start should be gentle
    // and the finish quick.
    readonly property int exit: Easing.InCubic
    // Symmetric. Only for a repeating pulse, where an asymmetric curve would
    // read as a stutter every cycle.
    readonly property int pulse: Easing.InOutSine
    // Material 3 Expressive's default spatial curve, taken from caelestia's
    // own tokens (plugin/src/Caelestia/Config/tokens.hpp). The 1.21 below is
    // a control-point y -- one of the curve's two Bezier handles, not the
    // curve it actually traces. That traced curve overshoots past 1 too, just
    // by far less than its handle would suggest: it tops out around 1.014
    // before settling back, so most of the travel is over inside the first
    // third and the tail is what reads as weight rather than as delay. The
    // overshoot is real even at that size -- BarPopup clamps the multiplier
    // it derives from this curve wherever the curve drives a size rather than
    // a position, so a card's height and width never grow past what is
    // actually behind them; see the clamp beside `card.reveal` in
    // BarPopup.qml. Used as `easing.type: Easing.Bezier; easing.bezierCurve:
    // Motion.spatialCurve`, which is why the trailing 1,1 endpoint is spelled
    // out -- QML wants the full control-point list, not just the two handles.
    readonly property var spatialCurve: [0.38, 1.21, 0.22, 1, 1, 1]
}
