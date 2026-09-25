import QtQuick
import qs.Config

// A card hung under one of the bar's pills, pointing back at the icon that
// opened it.
//
// An Item now, not a window -- Tier 3 folds every popup into the one
// PanelWindow the bar itself lives in (see BarWindow.qml), so there is no
// separate surface left for this to anchor of its own. `anchors.fill: parent`
// below reproduces what the four bool anchors on a PanelWindow used to buy:
// this Item still covers its screen edge to edge at the same origin, so a
// click that misses the card can still only be seen by a surface that covers
// where it landed, and dismiss-on-click-outside keeps working unchanged.
//
// This card no longer paints its own fill, shadow, outline, or the fillets/
// crescents that used to fuse it into its island by hand (`BarJunction.qml`,
// retired alongside this change -- its git history has the corner-by-corner
// geometry it took to fake one silhouette out of two windows' worth of
// pixels, for reference). `Blob.qml`, one instance per screen living in
// BarWindow.qml, draws all of that now: it reads this card's `cardRect`/
// `cardRadius`/`cardAlpha` below, does the same for the three islands and
// every other open card, and folds the lot through a signed-distance
// smooth-min -- one continuous shape, drawn once, instead of a card outline
// and an island outline hand-fitted to look joined. What is left in this
// file paints nothing a viewer can see except through `body`'s own content;
// `card` itself is now only a clip boundary and the thing that reports its
// rect to Blob.
FocusScope {
    id: root

    signal dismissed()

    // Centre of the pill, in bar coordinates. The bar and this popup are both
    // anchored across the full width of the same fused window, so the bar's x
    // needs no conversion to be used here.
    required property real anchorX

    property real popupWidth: 280
    property real popupHeight: 200

    // Exported for `Blob`, read through `BarOverlays.cards` -- the card's
    // own visible rect, its corner radius, and how solid it currently is
    // right now.
    //
    // `cardRect` is card ∩ cardClip in this Item's own coordinates, which are
    // also the fused window's: this popup fills that window at (0, 0) (see
    // `anchors.fill` below), so nothing here has to convert. The intersection
    // is taken explicitly rather than assumed: `card.x` is clamped to stay on
    // screen but nothing here clamps `card.height` against `cardClip`'s own
    // height the way the five popups with a `root.height` guard in their own
    // file do (see SettingsPopup.qml, NotificationPanel.qml, DzumaPopup.qml,
    // ClaudePanel.qml, SysPopup.qml) -- AudioPopup, CalendarPopup, DiskPopup,
    // MediaPopup and NetworkPopup carry no such guard at all, so a consumer
    // of this rect should see what is actually painted rather than what
    // `card`'s own properties claim, on the rare screen short enough for the
    // difference to matter. Empty while the card has nothing to show --
    // reveal at 0, or not `card.visible` at all -- so a consumer never has to
    // separately check `open` before trusting the size.
    readonly property rect cardRect: {
        if (!card.visible || card.reveal <= 0)
            return Qt.rect(0, 0, 0, 0);

        const x0 = Math.max(card.x, 0);
        const y0 = cardClip.y;
        const x1 = Math.min(card.x + card.width, root.width);
        const y1 = Math.min(cardClip.y + card.height, root.height);
        return Qt.rect(x0, y0, Math.max(0, x1 - x0), Math.max(0, y1 - y0));
    }

    // The one radius `Blob`'s union needs from this side of the join --
    // uniform now that the card paints no fill or line of its own that would
    // need squaring off where an island used to reach over a corner. The
    // blob's own smooth-min shapes that corner now (see `radius` on `card`
    // below, which carries no per-corner override any more).
    readonly property real cardRadius: card.radius

    // The card's effective alpha, for the per-card fade `Blob` reproduces.
    // Reads `card.opacity` and not the `reveal`-driven `visible` guard on
    // its own: opacity is what the OpacityAnimator below actually drives
    // frame to frame, including the fast fade-out that finishes well before
    // `reveal` unwinds all the way to 0 -- see the comment on `opacity`
    // further down for why the two are deliberately different speeds.
    // Forced to 0 once `card` is not visible at all so a popup that was
    // never entered, or whose Item is on its way out of existence, never
    // reports a stale nonzero alpha.
    readonly property real cardAlpha: card.visible ? card.opacity : 0

    // Held open by whoever owns the popup's state. Deliberately not the
    // loader's own lifetime: dropping this plays the card back into the icon,
    // and this Item has to outlive that animation to be seen doing it.
    // PopupLoader is what buys it that time and what writes this on the way
    // down, so every popup in the bar is loaded through one -- see
    // PopupLoader.qml. True by default because the Item is built before its
    // loader can reach it, and the card must be grown, not collapsed, on the
    // frame it first appears.
    property bool open: true

    // Vestigial: this used to feed WlrLayershell.namespace, giving every
    // popup its own layer-shell surface so hyprland.lua could blur/inset it
    // by name (qs-audio, qs-calendar, and so on -- the namespaces
    // hyprland.lua's per-popup blur rule still needs trimmed down to
    // whichever ones exist as separate windows). The popup is an
    // Item now and shares BarWindow's one namespace, so nothing reads this
    // property any more; it is kept only so the nine popups below, which each
    // still set it, don't each need a line touched for a property that costs
    // nothing to leave dead. A later cleanup pass can delete it along with
    // their assignments.
    property string namespace: "qs-popup"

    // Consumers fill the body inside the card, not the window and not the card
    // itself -- see `body` at the bottom of this file for why the card is no
    // longer the thing that content is sized against.
    default property alias content: body.data

    // Raised once this Item exists, so the first frame drawn is the collapsed
    // one and the card is seen to grow rather than arriving already grown.
    property bool _entered: false
    readonly property bool _shown: root._entered && root.open

    // Raised once the card has stopped arriving, and used for nothing but arming
    // the position and height animations below. A timer rather than a signal
    // because there is no one moment to listen for: the geometry comes from the
    // compositor and from a layout pass, and neither says when it is finished.
    //
    // Interval read off `revealAnimation.duration` itself rather than copied
    // as a second literal -- this timer exists purely to outlive the entrance,
    // so it has to fire exactly when that animation does and no sooner. It
    // used to be pinned to `Motion.slow`, back when the entrance was a scale
    // transform that also happened to run at `Motion.slow`; the two were
    // never actually related, and the day the entrance's own duration moved
    // to `Motion.spatial` without this one following, `_settled` started
    // arming 280ms before the card had finished arriving -- a popup whose
    // real size lands late (DzumaPopup's async drop image, decoding cold)
    // could open mid-window and be seen to fold a second time, animated,
    // right on top of its own entrance. Reading the animation's duration
    // back out closes that gap for good: the two cannot drift apart again
    // because there is only one number now, not two copies of it.
    property bool _settled: false

    Timer {
        interval: revealAnimation.duration
        running: true
        onTriggered: root._settled = true
    }

    // Fills whatever this popup was loaded into -- PopupLoader.qml's own Item,
    // a direct child of BarOverlays' root, which is itself the full size of
    // the fused window (see BarWindow.qml). That chain is what keeps this
    // Item's own (0, 0) the same point the window's is, which every
    // window-coordinate comment above and below this one is relying on.
    anchors.fill: parent

    // The most recently opened popup owns the keyboard. Every one of the nine
    // in-scope popups asks BarWindow for `WlrKeyboardFocus.OnDemand`
    // uniformly -- OnDemand grants the whole fused window keyboard input
    // once anything inside it wants it, but Qt Quick's active focus is still
    // a single item, and nothing Wayland-side picks which one. Binding
    // `focus` straight to `open` is what does: a FocusScope is handed
    // active focus when something gives it `focus: true`, and whichever
    // popup's `open` most recently flipped true is the one whose binding most
    // recently fired, so QML's own "last write wins" rule hands the keyboard
    // to the newest popup rather than an arbitrary one. That is the
    // deliberate policy for two popups open on different islands at once.
    focus: root.open

    // Click ownership follows the same "last write wins" policy the comment
    // above already settled on for the keyboard -- and needs its own copy of
    // it, because z and focus are unrelated in Qt Quick: nothing about
    // holding active focus changes stacking order, and every in-scope popup
    // is a full-window Item, so with two open at once (the same
    // two-popups-on-different-islands case as above) the one declared later
    // in BarOverlays.qml -- currently the Claude panel, whatever order its
    // PopupLoaders happen to be edited into in future -- would otherwise
    // always sit on top and eat every click, including ones landing squarely
    // on the other popup's own card. Stamping `z` with
    // the moment this popup last opened means the newest one is always
    // highest, whichever two are involved. `Date.now()` rather than a plain
    // counter: two popups cannot open in the same JS turn (opening one is
    // always a user action or a service event, never two in one tick), so
    // millisecond resolution can never tie, and it needs no state of its own
    // to increment. `0` while closed keeps a never-opened or long-closed
    // popup pinned under anything that has ever opened at all, rather than
    // racing it on `Date.now()` at load time.
    //
    // Set here, but read one level up: PopupLoader.qml mirrors this onto its
    // own `z`, because that Loader -- not this Item -- is the thing actually
    // declared as BarOverlays' child, which is the level Qt Quick's z really
    // stacks at (see the comment there).
    readonly property real _zStamp: root.open ? Date.now() : 0
    z: root._zStamp

    // Declared before the card, so it sits underneath and only ever sees the
    // clicks that missed it. This also covers the pill itself: the popup sits
    // above the bar groups in z (see BarOverlays.qml), so a second click on
    // the icon lands here and closes. Disabled while the card plays out -- the
    // Item outlives it by one animation, and a click in that time must not
    // re-close something already closing.
    //
    // This is also everything a window-level `mask` used to buy on top of the
    // same `enabled: root.open` gate: the old PanelWindow's input region went
    // empty in step with this MouseArea so a click meant for whatever the
    // card was covering could reach it during that last fifth of a second.
    // An Item has no input region of its own to gate -- it only ever eats a
    // click by having something enabled at that point -- so this MouseArea
    // disabling itself is now the whole of that behaviour, and the mask and
    // its empty `Region` fallback are simply gone rather than reimplemented.
    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.dismissed()
    }

    // Pins the join line this card hangs below, in window coordinates --
    // `Caelus.barHeight - Caelus.barInset`, the same number `Blob.joinY`
    // reads on the other side of the join (BarWindow.qml). `card` is this
    // Item's only child, positioned at its origin, so `card.y` reads as 0
    // everywhere below and this Item's own `y` is the one true offset a
    // window-coordinate consumer -- `cardRect` above -- has to add back in.
    //
    // `clip: true` keeps the card and its content from ever painting above
    // that line. A Tier 1 shadow needed a wide vertical offset to fake that
    // guarantee, because a `layer.effect`'s private texture ignores any clip
    // outside itself; Blob draws this card's shadow now, cast and clipped at
    // the identical line inside the shader instead (`uJoinY`, see `foldCard`
    // in shaders/blob.frag), so this clip is back to doing only what it
    // says: keeping `card`'s own content off the island's side of the seam.
    Item {
        id: cardClip

        x: 0
        y: Caelus.barHeight - Caelus.barInset
        width: root.width
        height: root.height - cardClip.y
        clip: true

        Rectangle {
            id: card

            // Centred under the pill, but never past a screen edge: the pills live
            // in the bar's right-hand group, so a card centred on one would other-
            // wise hang off the side of the screen.
            //
            // The stop is the island's outer edge, not the bar's group margin: a
            // group sits `barMargin` in from the screen, and the plate behind it
            // reaches `barIslandPad` further out still, so this is the line the
            // card visibly lines up with. It is also exactly what lets the notch
            // reach the last pill. The notch may come no closer than
            // `radiusPopover + 8` to a card corner without its base riding up the
            // rounded edge, and the rightmost pill's centre sits
            // `barIslandPad + pillWidth / 2` in from this stop -- 20px for the
            // narrowest pill on the bar, the menu star. Stopping 6px short of
            // here, as this did, put the notch that same 6px left of the icon it
            // is supposed to point at, and no closer no matter how the pill grew.
            readonly property int edgeStop: Caelus.barMargin - Caelus.barIslandPad

            // Where the card sits once fully open, clamped against its own final
            // width rather than against the live one. `width` now shrinks to
            // nothing at reveal 0 (see below), and clamping against that would
            // have the resting position itself slide as the card grows -- the
            // opposite of settling in place.
            //
            // Clamped against `root.width`, not `cardClip.width`: the two are
            // numerically identical (`cardClip` spans the full window), but the
            // clamp is conceptually about the screen the card must not run off
            // of, and `root` is the thing that is actually the screen. `card.x`
            // itself stays window-relative for the same reason -- `cardClip` sits
            // at `x: 0`, so a coordinate inside it and a coordinate inside the
            // window are the same number, and every place below that reads
            // `card.x` is relying on that, not on `card.x` having become
            // container-relative.
            property real openX: Math.round(Math.max(card.edgeStop, Math.min(root.width - root.popupWidth - card.edgeStop, root.anchorX - root.popupWidth / 2)))

            // The pills either side of the anchor change width as they live -- the
            // clock's countdown reflows once a second, a media title scrolls in --
            // and every one of those moves the anchor this card is centred on. Left
            // unanimated, an open card and its notch teleport sideways while you are
            // reading them. Short enough to keep the card feeling stuck to its pill,
            // and armed on the same gate as the height below: the screen width this
            // is clamped against is zero until the compositor configures the layer
            // surface, so an ungated card would slide in from the left edge on every
            // single open.
            Behavior on openX {
                enabled: root._settled
                NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
            }

            // The point the reveal grows outward from -- `openX` itself, unless
            // the pill it is anchored to sits inside that final span, in which
            // case the card should visibly extrude from the pill instead of from
            // one of its own corners. Clamped to the card's own span either way,
            // so a pill far outside it (the card is centred and stopped by an
            // edge) never drags the aperture off the card altogether.
            readonly property real originX: Math.max(card.openX, Math.min(card.openX + root.popupWidth, root.anchorX))

            // At reveal 1 this is `openX`, identical to Tier 1. At reveal 0 it is
            // `originX`, a zero-width point near the pill. Between the two, the
            // card's near edge is pinned to `originX` while its far edge sweeps
            // out to `openX` -- the same aperture idea `contentHeight`/`reveal`
            // already uses for height, applied to x instead of animating x on
            // its own Behavior, which would have fought this one for the property.
            x: card.originX - (card.originX - card.openX) * card.reveal

            // Zero: the join-line offset lives on `cardClip` now (see the
            // comment above it), and this card is `cardClip`'s only child,
            // positioned at that child's origin, so the card's top edge
            // still lands exactly on the join line it always has.
            y: 0

            // Multiplied by `reveal` rather than fixed at `root.popupWidth`: the
            // card is an aperture that grows out to its full width on the way
            // in, the same idea `height` already applies below, on the same
            // `reveal` so the two sweep out together instead of racing each
            // other. Clamped to 1 for the same reason `height` is -- see the
            // comment above `height` for why the clamp belongs on size and not
            // on `x`.
            width: Math.round(root.popupWidth * Math.min(card.reveal, 1))

            // What the card is when fully open, kept apart from `height` because
            // the two kinds of height change here are not the same event and must
            // not share one animation. This one is the popup learning its own size
            // -- a tab switch, a notification arriving -- and it resizes in place;
            // `reveal` below is the entrance, and it multiplies this rather than
            // competing with it for the same property.
            //
            // Never allowed to collapse. These cards size themselves from their own
            // content, and zero is a stable answer to that: a list given no height
            // creates no rows, reports no content height, and asks for no height in
            // turn. A floor breaks that circle -- the list gets a few rows' worth of
            // space, measures itself honestly, and the card grows to fit. The
            // comparison also catches a height that is briefly not a number, which
            // NaN-safe arithmetic below cannot.
            property real contentHeight: root.popupHeight > 80 ? root.popupHeight : 80

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
            Behavior on contentHeight {
                enabled: root._settled
                NumberAnimation { duration: Motion.slow; easing.type: Motion.standard }
            }

            // The entrance. The card is an aperture onto a body that is already at
            // its full open size, so growing this from 0 uncovers that body a row
            // at a time and the card is seen to come out of the bar -- which the
            // scale transform this replaces could never do. Scaling squashed the
            // content on the way in and sprang it back, so a card read as popping
            // into place near the bar rather than as extruding from it.
            //
            // Multiplied into `height` rather than animating `height` directly, so
            // that an entrance and a content resize can be in flight at the same
            // time without two animations writing one property.
            property real reveal: root._shown ? 1 : 0

            // Material 3 Expressive's default spatial motion, the pairing
            // caelestia opens every one of its panels on -- see Motion.qml. The
            // overshoot in the curve is what keeps half a second from reading slow.
            // Given an id so the settle Timer up in `root` can read this
            // animation's own duration back out instead of carrying a second,
            // separately-typed copy of the same number -- see `_settled` above.
            Behavior on reveal {
                NumberAnimation {
                    id: revealAnimation
                    duration: Motion.spatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Motion.spatialCurve
                }
            }

            // Clamped to 1 here and in `width` below, but not in `x` above:
            // `spatialCurve` overshoots past 1 (it peaks around 1.014, not at
            // its own 1.21 control point, which names a handle and not the
            // curve's actual extreme) on the way to settling, and that overshoot
            // is exactly what gives the entrance its weight when it is the
            // card's *position* doing the travelling. Size is different --
            // `body` behind this aperture is fixed at the card's true open
            // dimensions, so a `height`/`width` that overshoots past them
            // uncovers a strip of bare `popupBg` with no content under it,
            // which then springs back a moment later. Clamping only the
            // multiplier used for size leaves the position formula above free
            // to keep overshooting, so the card still arrives with the same
            // weight -- it just never grows past what is actually behind it.
            height: Math.round(card.contentHeight * Math.min(card.reveal, 1))

            clip: true

            // Gates `cardRect`/`cardAlpha` above: both read `card.visible`
            // before anything else, so a card whose reveal hasn't started
            // yet -- the frame before an entrance, or after `PopupLoader`
            // has let an exited window go dark -- reports itself absent to
            // Blob instead of a zero-size rect at some stale position.
            visible: card.reveal > 0

            // Uniform, unlike an earlier bar's per-corner override that used to
            // square the two top corners off wherever an island reached over
            // them: `Blob`'s smooth-min shapes that overlap now, so a single
            // radius is all this side of the join needs to report -- see
            // `cardRadius` above.
            radius: Caelus.radiusIsland

            // Transparent: Blob draws the fill, in the same pass as the three
            // islands and every other open card (see the file comment at the
            // top), so this Rectangle paints nothing of its own -- it exists
            // now only to clip `body`'s content to the card's shape and to
            // report `cardRect`/`cardRadius`/`cardAlpha` above for Blob to
            // draw instead.
            color: "transparent"

            // Zero always: Blob draws the stroke around the merged
            // island+card silhouette now (BarWindow.qml), and a Rectangle's
            // own border would only double that line up a pixel inside it.
            border.width: 0

            // On the card and not on the window: a Component.onCompleted declared on
            // a derived type would replace this one, and every popup built on this
            // would then stay collapsed.
            Component.onCompleted: root._entered = true

            // Opacity sits on a State rather than on a binding to `_shown`: an
            // OpacityAnimator pokes the scene graph directly every frame, and a
            // property still bound elsewhere -- the way `x` and `reveal` above
            // still are -- would have the binding fight it back on the next
            // GUI-thread tick.
            //
            // Kept alongside the reveal, and deliberately far shorter than it. Qt
            // has no HeightAnimator (Animators cover x, y, scale, rotation and
            // opacity, nothing else), so the reveal runs on the GUI thread and
            // stalls with it when a Process callback or a chart rebuild lands mid-
            // entrance; this fade does not, so something is always seen to happen
            // on time. It is also what lets the window still be torn down on
            // PopupLoader's existing hold: the card is fully invisible long before
            // a retract at spatial speed would have finished.
            opacity: 0

            states: State {
                name: "shown"
                when: root._shown
                PropertyChanges { target: card; opacity: 1 }
            }

            // Runs on the render thread, so the card's fade keeps going even when
            // the GUI thread is busy -- a Process callback, a chart rebuild --
            // which used to make every popup's entrance stutter. See roadmap S6.4.
            transitions: Transition {
                OpacityAnimator { target: card; duration: Motion.fast }
            }

            focus: true
            Keys.onEscapePressed: root.dismissed()

            // The card is a plain Rectangle, so without this every click on its own
            // background would fall through to the dismiss handler underneath and
            // shut the popup you were aiming at. First child, so it stays below
            // every control the popup actually has.
            MouseArea { anchors.fill: parent }

            // Everything a popup puts inside itself. Sized to the card's *open*
            // width and height rather than to the card, so that a reveal in
            // progress uncovers it instead of squeezing it: content anchored to
            // a card whose width and height change every frame would squash and
            // stretch, which is the entrance this file just stopped doing.
            // `x` follows the same aperture idea the card's own `x` does, but
            // the other way round -- the card slides right as it grows towards
            // `openX`, so the body has to slide an equal distance left underneath
            // it to keep its content sitting still at its resting position.
            //
            // There is no notch on this card any more. It existed to bridge the 8px
            // of wallpaper between the island and the popup and to say which pill
            // you had opened. The gap is gone, and an arrow would now have to be
            // drawn 7px up inside the island -- in a different, translucent window
            // -- where two glass surfaces over one another would double-composite
            // into a visible seam rather than into a pointer.
            Item {
                id: body

                x: card.openX - card.x
                width: root.popupWidth
                height: card.contentHeight
            }
        }
    }
}
