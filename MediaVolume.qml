import QtQuick
import qs.Config
import qs.Services

// The transport row's own volume control -- collapsed to one glyph most of
// the time so the row reads as MediaButton's five glyphs plus one more, and
// only grows a slider out of that glyph while someone is actually reaching
// for it. Placed at the right end of the transport row and overlaid on top
// of it: expanding does not widen the card (that read as odd once it
// shipped) but grows this control's own `implicitWidth` leftwards in
// place, covering the row -- DesktopMedia.qml fades the other transport
// buttons out from underneath as this grows over them. `poke()` is what
// its card-wide wheel handler calls so turning the volume down from
// anywhere over the card still shows the number changing.
//
// The glyph and the reused VolumeSlider occupy the same box and crossfade
// rather than sit side by side: both are bound to the same `_icon`, so the
// glyph does not visibly change identity the moment the slider grows out of
// it, and there is never a second, redundant volume icon drawn next to the
// first. The glyph stays anchored to the right edge -- the one edge that
// never moves as the control grows leftward -- so it reads as the fixed
// point the slider extends out of, not as something sliding away with it.
Item {
    id: root

    // How long the row stays out after the thing that opened it stops --
    // named and up top rather than buried in the Timer below, since both
    // numbers are tuning, not structure. Short: reaching for the other
    // transport buttons again is the whole point of collapsing at all, and
    // the first version of this row (1.5s flat) made that feel stuck.
    readonly property int collapseHoldMs: 400        // pointer leaving, or a drag ending
    readonly property int collapseWheelHoldMs: 800   // the last wheel notch, pointer elsewhere

    // The MprisPlayer whose own stream this drives -- same reasoning
    // MediaPopup's per-row VolumeSlider and DesktopMedia's own volume row
    // give: this player's loudness, not the sink's. Media.streamFor(player)
    // is the source of truth, not MPRIS's own (often absent, sometimes
    // wrong) volume property -- see Services/Media.qml.
    property var player: null

    readonly property var _stream: Media.streamFor(root.player)
    readonly property bool _adjustable: root._stream?.ready ?? false
    readonly property real _volume: root._stream?.audio?.volume ?? 0
    readonly property bool _muted: root._stream?.audio?.muted ?? false

    // A plain two-way split on level; muted no longer collapses this to
    // volume_off, since MuteGlyph overlays its slash on whichever of the two
    // is showing rather than swapping the glyph. MediaPopup's own row never
    // needed the split because a full row was always in view; sitting
    // collapsed to a single glyph most of the time, this is the only volume
    // readout there is until the slider is out, so it earns the split
    // MediaPopup's row leaves to a caller.
    readonly property string _icon: root._volume >= 0.5 ? "volume_up" : "volume_down"

    // Set for the whole span of a press from the scrub overlay below --
    // from the first pixel of a click to its release, whether that press
    // turns into a drag or stays a click -- so the row can never shrink out
    // from under a held-down button, whether or not the pointer is still
    // inside the row's own bounds (a drag that scrubs past either edge
    // keeps receiving events; see `scrub` below).
    property bool _dragActive: false

    // True while hovered, for a grace period after the pointer leaves or
    // after the last poke(), or for as long as a press is held -- any one
    // of the three keeps the slider out, and the `_adjustable` guard means
    // a player with no stream never grows one at all, whatever poke() or
    // the pointer do.
    readonly property bool expanded: root._adjustable
        && (hover.hovered || collapseTimer.running || root._dragActive)

    // What the row shrinks back to -- the glyph's own rendered footprint,
    // read straight off the glyph rather than guessed, so a font or icon
    // swap can never leave this stale.
    readonly property real collapsedWidth: glyph.implicitWidth

    // How far across the row the control reaches once expanded -- a plain
    // (not readonly) property, so a caller covering a wider or narrower row
    // can override it; today's ~90px of track and percent label beyond the
    // glyph is just the default that shipped with the first version of
    // this control.
    property real expandedWidth: root.collapsedWidth + 90

    implicitWidth: root.expanded ? root.expandedWidth : root.collapsedWidth
    implicitHeight: Math.max(glyph.implicitHeight, slider.implicitHeight)
    // Explicit rather than left to default -- a bare Item's width does not
    // follow its own implicitWidth unless something says so, and a caller
    // that places this outside a Layout (a scratch harness, say) still
    // needs the box to actually be the size it reports. Inside a RowLayout
    // this is redundant with what the layout already does, and harmless.
    width: implicitWidth
    height: implicitHeight

    Behavior on implicitWidth {
        NumberAnimation { duration: Motion.base; easing.type: Motion.standard }
    }

    // One timer, re-armed with whichever hold applies to whatever just
    // happened -- `_beginCollapse` below is the only thing that ever
    // touches its `interval`, so the two hold lengths above are the only
    // two values it is ever set to.
    Timer {
        id: collapseTimer
        interval: root.collapseHoldMs
    }

    function _beginCollapse(ms) {
        collapseTimer.interval = ms;
        collapseTimer.restart();
    }

    // Called by the card's own wheel handler on every notch turned anywhere
    // over it, not just over this control -- expands (or re-arms) exactly
    // as if the pointer had just arrived on the glyph, on the longer of the
    // two holds since a wheel notch is the one way to reveal this row
    // without the pointer ever sitting over it (see `collapseWheelHoldMs`
    // above). A no-op with nothing to adjust, so a card with a silent
    // player never pops a slider open over a wheel that did nothing.
    function poke() {
        if (root._adjustable) root._beginCollapse(root.collapseWheelHoldMs);
    }

    // HoverHandler, not a hovering MouseArea: a MouseArea here would claim
    // the hover for itself and never let it reach whatever sits behind or
    // beside this control -- MediaButton.qml's own glyphs hit the same trap
    // and give the same fix. Disabled outright with no stream, so hovering
    // a dimmed glyph never starts the countdown that would otherwise expand
    // nothing.
    HoverHandler {
        id: hover
        enabled: root._adjustable
        onHoveredChanged: if (!hovered) root._beginCollapse(root.collapseHoldMs);
    }

    // Where a plain (non-drag) press lands, in the same two categories the
    // reused VolumeSlider already knows about -- its own icon column, or
    // its own track. Read through mapToItem rather than guessed, so a font
    // or spacing change in VolumeSlider.qml can never leave this stale, and
    // found through its iconItem/trackItem rather than by child index. Its
    // percent label answers neither category, same as it answers no click
    // today.
    function _regionAt(x) {
        const icon = slider.iconItem;
        const track = slider.trackItem;
        const iconRight = icon.mapToItem(root, icon.width, 0).x;
        const trackLeft = track.mapToItem(root, 0, 0).x;
        const trackRight = track.mapToItem(root, track.width, 0).x;
        if (x <= iconRight) return "glyph";
        if (x >= trackLeft && x <= trackRight) return "track";
        return "none";
    }

    // The same absolute mapping VolumeSlider's own track MouseArea uses --
    // `mouse.x / width` -- against the track's real geometry rather than
    // from inside it: a click landing here has to be answered by this file
    // now, on top of the reused component, since `scrub` below (declared
    // last, so it stacks above both the glyph and the slider) wins every
    // press before VolumeSlider's own MouseArea ever sees it.
    function _absoluteAtTrack(x) {
        const track = slider.trackItem;
        const local = track.mapFromItem(root, x, 0).x;
        return Math.max(0, Math.min(1, local / track.width));
    }

    // ── collapsed glyph ──────────────────────────────────────
    // Its own MouseArea rather than the slider's: with no stream the slider
    // never appears at all, and this is what a click or a wheel notch over
    // a dimmed player's control has to land on instead.
    MuteGlyph {
        id: glyph

        // Right, not left: the control grows leftward out of its right
        // edge (see the header comment), so anchoring here is what keeps
        // the glyph sitting still while `implicitWidth` changes underneath
        // it, instead of sliding along with the growing left edge.
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        glyph: root._icon
        muted: root._muted
        color: root._muted ? Colors.mediaMeta : Colors.mediaActive
        // Dimmed and fixed, not merely faded to nothing, while there is no
        // stream to turn down -- MediaButton's own `available` does the
        // same with the same 0.35. Faded to nothing instead once the
        // slider is what is actually shown, so the two never draw at once.
        opacity: root._adjustable ? (root.expanded ? 0 : 1) : 0.35
        size: 16

        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            // Not just dim: disabled outright once the slider has taken
            // over the same box, the same "opacity alone is not enough"
            // caveat MediaButton.qml's own bottomHitMargin comment and
            // DesktopMedia's old `enabled: volumeReveal.revealed` both
            // already had to work around -- otherwise this invisible area
            // would keep winning clicks meant for the slider drawn on top
            // of it.
            enabled: root._adjustable && !root.expanded
            cursorShape: Qt.PointingHandCursor
            onClicked: Media.toggleMute(root.player)
            onWheel: wheel => {
                Media.stepVolume(root.player, wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                root.poke();
            }
        }
    }

    // ── expanded slider ──────────────────────────────────────
    // Reused exactly as MediaPopup's own per-player row reuses it -- same
    // four bindings, same three signals -- with one addition: `icon` is
    // bound to the same `_icon` the collapsed glyph shows, so the crossfade
    // above never has to swap what the icon actually says, only whether
    // the glyph or this slider is the one drawing it.
    //
    // Anchored left and right rather than given a fixed width: it fills
    // whatever `implicitWidth` the control currently has, which is what
    // lets it read as growing out to meet the fixed glyph on the right
    // rather than as a fixed-size element the control happens to contain.
    VolumeSlider {
        id: slider

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: root._icon
        accent: Colors.mediaActive
        value: root._volume
        muted: root._muted
        // Same disabled-not-just-invisible reasoning as the glyph's own
        // MouseArea above, mirrored: collapsed, this must never win a
        // click or a wheel notch the glyph drawn over it is answering.
        enabled: root.expanded
        opacity: root.expanded ? 1 : 0
        onMoved: v => { Media.setVolume(root.player, v); root.poke(); }
        onToggled: Media.toggleMute(root.player)
        onStepped: delta => { Media.stepVolume(root.player, delta); root.poke(); }

        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    }

    // ── scrub overlay ────────────────────────────────────────
    // Sits on top of everything above once expanded and answers every
    // press itself, wherever it lands -- reaching back across the row to
    // the slider's own knob was the entire complaint this exists to fix,
    // so nothing here waits for a press to find any particular pixel of
    // the reused controls underneath. Declared last, so it stacks above
    // the glyph and the slider and wins every press while it is enabled;
    // VolumeSlider's own `onMoved`/`onToggled`/`onStepped` above are left
    // wired rather than stripped out, but with this on top of them they
    // never fire in practice -- harmless, and one less thing to put back
    // if this overlay is ever removed.
    MouseArea {
        id: scrub

        anchors.fill: parent
        enabled: root.expanded
        cursorShape: scrub.dragging ? Qt.SizeHorCursor : Qt.PointingHandCursor

        property bool dragging: false
        property real startX: 0
        property real startVolume: 0
        property string pressRegion: "none"

        // Held for the whole press: `root._dragActive` (used by `expanded`
        // above) has to be true from this first pixel, not only once the
        // threshold below decides it is a drag, so the row cannot shrink
        // between a press landing and that decision being made.
        onPressed: mouse => {
            scrub.dragging = false;
            scrub.startX = mouse.x;
            scrub.startVolume = root._volume;
            scrub.pressRegion = root._regionAt(mouse.x);
            root._dragActive = true;
        }

        // Relative, not absolute: the whole point of this overlay is that
        // the cursor is already wherever it needs to be the moment the
        // slider has grown out to it, so a drag moves the volume by how
        // far the pointer has travelled from the press, not to wherever it
        // happens to be sitting -- the full expanded width is worth 100%,
        // the same scale a drag across the reused VolumeSlider's own track
        // would be, just measured from the press instead of from the
        // track's left edge. A MouseArea keeps receiving these once
        // pressed even past its own edges, so a drag run past either side
        // of the row still tracks.
        onPositionChanged: mouse => {
            if (!scrub.pressed) return;
            const dx = mouse.x - scrub.startX;
            if (!scrub.dragging && Math.abs(dx) > 4) scrub.dragging = true;
            if (scrub.dragging) {
                Media.setVolume(root.player, scrub.startVolume + dx / root.expandedWidth);
                root.poke();
            }
        }

        // Anything under that threshold is a click, not a drag, and
        // answered exactly as it would have been before this overlay
        // existed: the glyph mutes, the track jumps to that x. Held for
        // `collapseHoldMs`, the same hold a drag's own release gets below
        // -- a click is over the instant it lands, same as a drag ending.
        onReleased: mouse => {
            if (!scrub.dragging) {
                if (scrub.pressRegion === "glyph") Media.toggleMute(root.player);
                else if (scrub.pressRegion === "track")
                    Media.setVolume(root.player, root._absoluteAtTrack(mouse.x));
            }
            scrub.dragging = false;
            root._dragActive = false;
            root._beginCollapse(root.collapseHoldMs);
        }

        onCanceled: {
            scrub.dragging = false;
            root._dragActive = false;
            root._beginCollapse(root.collapseHoldMs);
        }

        // Not left to fall through to the slider underneath -- this sits
        // on top of it and would otherwise swallow the notch silently.
        // Same step, same poke() as every other wheel target on this
        // control.
        onWheel: wheel => {
            Media.stepVolume(root.player, wheel.angleDelta.y > 0 ? 0.05 : -0.05);
            root.poke();
        }
    }
}
