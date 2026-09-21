import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import qs.Config

// A card hung under one of the bar's pills, pointing back at the icon that
// opened it.
//
// Anchored to all four edges rather than to the card's own corner: a click that
// misses the card can only be seen by a surface that covers where it landed, and
// dismiss-on-click-outside is what every one of these popups wants.
PanelWindow {
    id: root

    signal dismissed()

    // Centre of the pill, in bar coordinates. The bar and this window are both
    // anchored across the full width of the same screen from the same corner,
    // so the bar's x needs no conversion to be used here.
    required property real anchorX

    property real popupWidth: 280
    property real popupHeight: 200

    // Held open by whoever owns the popup's state. Deliberately not the loader's
    // own lifetime: dropping this plays the card back into the icon, and the
    // window has to outlive that animation to be seen doing it. PopupLoader is
    // what buys it that time and what writes this on the way down, so every
    // popup in the bar is loaded through one -- see PopupLoader.qml. True by
    // default because the window is built before its loader can reach it, and
    // the card must be grown, not collapsed, on the frame it first appears.
    property bool open: true

    property string namespace: "qs-popup"

    // Consumers fill the card, not the window.
    default property alias content: card.data

    // Raised once the window exists, so the first frame drawn is the collapsed
    // one and the card is seen to grow rather than arriving already grown.
    property bool _entered: false
    readonly property bool _shown: root._entered && root.open

    // Raised once the card has stopped arriving, and used for nothing but arming
    // the position and height animations below. A timer rather than a signal
    // because there is no one moment to listen for: the geometry comes from the
    // compositor and from a layout pass, and neither says when it is finished.
    property bool _settled: false

    Timer {
        interval: 220
        running: true
        onTriggered: root._settled = true
    }

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // OnDemand and not Exclusive: these cards are read beside the thing they
    // describe, so none of them may hold the keyboard while open.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: root.namespace
    color: "transparent"

    // The window is the whole screen and sits on the overlay layer, so for as
    // long as it exists it is also what every click on that screen lands on.
    // That is exactly right while the card is open -- clicking off it is how you
    // dismiss it -- and exactly wrong for the fifth of a second it now spends
    // leaving: a click meant for whatever the card was covering must not be
    // eaten by something already on its way out. An empty region hands those
    // milliseconds back; a null mask is the default, the whole surface.
    mask: root.open ? null : closedMask

    Region { id: closedMask }

    // Declared before the card, so it sits underneath and only ever sees the
    // clicks that missed it. This also covers the pill itself: the popup is on
    // the overlay layer, so a second click on the icon lands here and closes.
    // Disabled while the card plays out -- the window outlives it by one
    // animation, and a click in that window must not re-close something already
    // closing.
    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.dismissed()
    }

    Rectangle {
        id: card

        // Centred under the pill, but never past a screen edge: the pills live
        // in the bar's right-hand group, so a card centred on one would other-
        // wise hang off the side of the screen.
        x: Math.round(Math.max(14, Math.min(root.width - width - 14, root.anchorX - width / 2)))

        // The pills either side of the anchor change width as they live -- the
        // clock's countdown reflows once a second, a media title scrolls in --
        // and every one of those moves the anchor this card is centred on. Left
        // unanimated, an open card and its notch teleport sideways while you are
        // reading them. Short enough to keep the card feeling stuck to its pill,
        // and armed on the same gate as the height below: the screen width this
        // is clamped against is zero until the compositor configures the layer
        // surface, so an ungated card would slide in from the left edge on every
        // single open.
        Behavior on x {
            enabled: root._settled
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        // The bar is 40 tall; the rest is the gap the pills already float in.
        y: 46

        width: root.popupWidth
        // Never allowed to collapse. These cards size themselves from their own
        // content, and zero is a stable answer to that: a list given no height
        // creates no rows, reports no content height, and asks for no height in
        // turn. A floor breaks that circle -- the list gets a few rows' worth of
        // space, measures itself honestly, and the card grows to fit. The
        // comparison also catches a height that is briefly not a number, which
        // NaN-safe arithmetic below cannot.
        height: root.popupHeight > 80 ? root.popupHeight : 80

        // Popups that size to their content change height while open -- a tab
        // switch, a notification arriving. Animated so the card is seen to fold
        // rather than to jump.
        //
        // Armed late, and not merely left to QML's rule that a Behavior does not
        // run during creation. A popup's real height is not known at creation: a
        // window anchored to the screen is told its size by the compositor a
        // round trip later, and a layout does not measure itself until it has
        // been through a pass. Both land after creation, when the Behavior is
        // already live, so without the gate every card appeared at the 80px
        // floor above and was then seen to unfold to its true size -- a resize
        // that was never a change of mind, only the card learning what it was.
        Behavior on height {
            enabled: root._settled
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        radius: 18
        color: Colors.popupBg
        border.width: 1
        border.color: Colors.popupBorder

        // On the card and not on the window: a Component.onCompleted declared on
        // a derived type would replace this one, and every popup built on this
        // would then stay collapsed.
        Component.onCompleted: root._entered = true

        // Grows out of the pill rather than sliding in from a screen edge. The
        // origin is the point of the card nearest the icon, so it reads as the
        // icon unfolding and not as a window that happened to appear near it.
        property real grow: root._shown ? 1 : 0.88
        opacity: root._shown ? 1 : 0

        Behavior on grow { NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        transform: Scale {
            origin.x: Math.max(0, Math.min(card.width, root.anchorX - card.x))
            origin.y: 0
            xScale: card.grow
            yScale: card.grow
        }

        focus: true
        Keys.onEscapePressed: root.dismissed()

        // The card is a plain Rectangle, so without this every click on its own
        // background would fall through to the dismiss handler underneath and
        // shut the popup you were aiming at. First child, so it stays below
        // every control the popup actually has.
        MouseArea { anchors.fill: parent }

        // The notch, pointing back at the pill that opened this. Its base sits a
        // pixel inside the card so that the card's own top border does not draw
        // a line across it, and it is a child of the card so the grow animation
        // above carries it.
        Shape {
            x: Math.round(Math.max(20, Math.min(card.width - 20, root.anchorX - card.x)))
            y: -7

            // Open path: the fill closes it, the stroke does not, so the two
            // sloped sides are outlined and the base is left alone.
            ShapePath {
                fillColor: card.color
                strokeColor: card.border.color
                strokeWidth: 1

                startX: -8
                startY: 8

                PathLine { x: 0; y: 0 }
                PathLine { x: 8; y: 8 }
            }
        }
    }
}
