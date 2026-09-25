import QtQuick
import QtQuick.Effects
import qs.Config

// The card every OSD in this shell is drawn on. One file rather than three
// copies, because an OSD's whole job is to be recognised in the quarter of a
// second it is on screen -- volume, brightness and keyboard layout have to
// arrive as the same object saying different things, or each one has to be
// read before it can be understood.
//
// Wide and short on purpose. The earlier cards stacked a 48px glyph over a
// 48px number and came out nearly square, which reads as a dialog waiting for
// an answer; this reads as a status line, which is what it is -- and a status
// line is small. It is up for a second and a half over whatever you were
// looking at, so it takes the least screen it can and still be read at a
// glance.
Item {
    id: root

    // What goes inside the padding. Declared as the default property so a
    // caller writes `OsdCard { Text {...} }` and never mentions the layout.
    default property alias content: body.data

    // Raised by the window once it exists, so the entrance has a collapsed
    // first frame to grow from rather than snapping in at full size.
    property bool shown: false

    implicitWidth: 292
    implicitHeight: 52

    Rectangle {
        id: card

        anchors.fill: parent
        // The island radius, not a square corner and not a full pill: the
        // bar's own surfaces are the shape this shell means by "a panel", and
        // an OSD is one of those for a second and a half.
        radius: Caelus.radiusIsland
        // Translucent rather than solid, and blurred by the compositor -- see
        // the `quickshell-osd-blur` layer rule in hyprland.lua. A solid card
        // reads as a foreign object dropped on the desktop; this one is made
        // of what is behind it, the same way the bar's islands are. 0.72 was
        // opaque enough that the blur behind it had nothing left to show
        // through and the card looked flat; this is a little heavier than the
        // bar's own 0.28 -- an OSD carries a number that has to be read in the
        // second it is up, and it can land on anything -- and no heavier.
        color: Qt.rgba(Colors.surfaceRaised.r, Colors.surfaceRaised.g,
                       Colors.surfaceRaised.b, 0.42)
        // The accent, not the islands' own edge. barIslandBorder is a dark
        // structural line that works where a surface meets the wallpaper
        // along a 44px strip; a card that lands in the middle of a window for
        // a second and a half needs an edge that says where it stops, and in
        // dynamic mode this is the wallpaper's own colour, which is the point.
        border.width: Caelus.borderWidth
        border.color: Colors.accent

        // Collapsed-and-invisible baseline. The "shown" state below is the
        // only thing that ever moves opacity or scale now, so neither is
        // also a binding for an Animator to fight -- see roadmap S6.4.
        opacity: 0
        // Rises into place rather than appearing at size. Small -- 0.96, not
        // 0.8 -- because an OSD that bounces draws the eye to the animation
        // instead of to the number it came to report.
        scale: 0.96

        Item {
            id: body

            anchors.fill: parent
            anchors.margins: Caelus.spaceWide
        }
    }

    // Lifts the card off whatever it is covering. Without it the OSD sits
    // flat on a busy wallpaper and its border is the only thing separating
    // the two, which is not enough on a light image.
    //
    // `card` carries no layer.enabled, but MultiEffect does not need one: Qt6
    // auto-creates an internal ShaderEffectSource proxy for any source item
    // that isn't already its own texture provider, so this remains a valid
    // source either way. opacity/scale used to just bind to card's; now both
    // get their own Animators in the same Transition as card's below, so the
    // two start on the same frame instead of the shadow trailing a
    // GUI-thread binding update a frame behind a render-thread-driven card.
    MultiEffect {
        id: shadow

        anchors.fill: card
        source: card
        shadowEnabled: true
        shadowBlur: 0.7
        shadowOpacity: 0.45
        shadowVerticalOffset: 3
        opacity: 0
        scale: 0.96
        z: -1
    }

    // One state for both surfaces, so they can never disagree about whether
    // they are shown.
    states: State {
        name: "shown"
        when: root.shown
        PropertyChanges { target: card; opacity: 1; scale: 1 }
        PropertyChanges { target: shadow; opacity: 1; scale: 1 }
    }

    // OpacityAnimator/ScaleAnimator run on the scene graph's render thread,
    // so the rise-and-fade keeps playing even when the GUI thread is stuck on
    // a Process callback or a chart rebuild. Animator has no `targets` list,
    // only a single `target`, so card and shadow each need their own; all
    // four declared in one Transition still start on the same frame, which is
    // what keeps the shadow in lockstep with the card.
    transitions: Transition {
        OpacityAnimator { target: card; duration: Motion.fast }
        OpacityAnimator { target: shadow; duration: Motion.fast }
        ScaleAnimator { target: card; duration: Motion.base; easing.type: Motion.standard }
        ScaleAnimator { target: shadow; duration: Motion.base; easing.type: Motion.standard }
    }
}
