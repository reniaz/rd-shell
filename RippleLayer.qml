import QtQuick
import QtQuick.Effects
import qs.Config

// Material-style state layer: one soft circle of ink per press, expanding
// and fading out from wherever the pointer actually went down, instead of
// the whole surface lighting up evenly. Generic on purpose -- it only knows
// a colour, a peak strength and where to start from; Pill.qml decides which
// token feeds those.
//
// Cut to the pill's own curve by a mask, not by `clip`: Qt Quick's `clip`
// is always the bounding box, `radius` or not, so a clipped Rectangle let
// the ink's square corners show past a capsule this rounded
// (Caelus.radiusPill is 999 -- a half-stadium end). The mask's layer only
// exists while ink is on screen, so an idle pill pays for no offscreen
// texture at all.
//
// Plain filled circles, not a true radial gradient. QtQuick's own
// `Rectangle.gradient` is linear-only, and the real radial gradient types
// (QtQuick.Shapes' ShapePath fill, Qt5Compat.GraphicalEffects) cost either a
// hand-rolled path or a deprecated module for something that, at the
// alpha this bar actually asks for (`Caelus.opacityPress`, a few percent),
// an anti-aliased solid circle fading via `opacity` cannot be told apart
// from -- the "soft edge" a gradient would buy is already below what the
// wash is tuned to show. Simplicity over the fancier machinery.
Item {
    id: root

    property color rippleColor: Colors.fg
    property real peakOpacity: Caelus.opacityPress
    // The caller's own radius, not a literal -- Pill passes hoverBg's, so
    // the two shapes can never drift apart.
    property real cornerRadius: 0

    // Ink circles still alive; the mask below is only switched on while
    // this is above zero.
    property int _live: 0

    Item {
        id: inkHost

        anchors.fill: parent
        layer.enabled: root._live > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: shapeMask
            // Same threshold/spread pair Wallpaper.qml's reveal mask uses:
            // the step sits mid-way through the rounded rect's own
            // antialiased rim, so the cut edge stays smooth.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.04
        }
    }

    // The shape the ink is cut to. `opacity: 0` rather than
    // `visible: false`, the same reason Wallpaper.qml's revealShape gives:
    // it must keep producing a live layer texture while drawing nothing.
    Rectangle {
        id: shapeMask

        anchors.fill: parent
        radius: root.cornerRadius
        color: "#ffffff"
        opacity: 0
        layer.enabled: root._live > 0
    }

    // One ripple per call, each owning its own animation and cleaning
    // itself up when it finishes -- a second press before the first ripple
    // has faded spawns a second circle alongside it rather than restarting
    // or fighting over shared state, so rapid clicks layer ink instead of
    // ever leaving one stuck mid-fade.
    function spawn(x, y) {
        const ink = rippleComponent.createObject(inkHost, { originX: x, originY: y });
        root._live++;
        ink.play();
    }

    Component {
        id: rippleComponent

        Rectangle {
            id: ink

            property real originX: 0
            property real originY: 0
            // The pill's diagonal, not just its width: a press landing in a
            // corner still has to reach the far corner before the mask above
            // cuts it off, and the diagonal is the longest that trip ever
            // gets. Doubled so the circle's radius (half this) covers it.
            property real maxDiameter: Math.hypot(root.width, root.height) * 2

            x: originX - maxDiameter / 2
            y: originY - maxDiameter / 2
            width: maxDiameter
            height: maxDiameter
            radius: width / 2
            color: root.rippleColor
            opacity: 0
            scale: 0
            antialiasing: true

            function play() {
                anim.start();
            }

            // Expand decelerates (Motion.standard) like everything else that
            // grows in this shell; the fade accelerates (Motion.exit)
            // instead of mirroring it, so the ink reads as dissolving near
            // the end of its life rather than fading at a steady rate the
            // whole way -- the same asymmetric pairing Motion.qml's own
            // comments use for enter/exit curves elsewhere.
            ParallelAnimation {
                id: anim

                NumberAnimation {
                    target: ink
                    property: "scale"
                    from: 0
                    to: 1
                    duration: Motion.ripple
                    easing.type: Motion.standard
                }
                NumberAnimation {
                    target: ink
                    property: "opacity"
                    from: root.peakOpacity
                    to: 0
                    duration: Motion.ripple
                    easing.type: Motion.exit
                }

                onStopped: {
                    root._live--;
                    ink.destroy();
                }
            }
        }
    }
}
