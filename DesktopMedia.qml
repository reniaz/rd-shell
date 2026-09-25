import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Config
import qs.Services

// The now-playing card under the desktop clock. Spotify only, never
// whichever player the bar pill or MediaPopup happen to be showing (see
// Media.spotify and the contract's Round 3/4) -- Firefox or anything else
// playing at the same time never makes this card appear, move, or change.
//
// Two faces, not one: idle is nothing but a bar visualizer the size of the
// bar strip's own island, fully transparent; hovering it grows the real
// card out of that same footprint. `root` is always exactly whichever of
// the two is currently showing -- DesktopWidgets.qml masks the window's
// input to this item's own bounds, so the idle visualizer being small is
// what lets clicks fall through to the empty desktop around it, and the
// card being its full size when expanded is what makes the card clickable
// at all.
Item {
    id: root

    readonly property var spotify: Media.spotify
    readonly property bool playing: root.spotify?.isPlaying ?? false

    // Media.titleOf() strips a title's own "(feat. ...)" clause once
    // MediaArtists has taken those names out of it (see Media.trackInfo) --
    // falling back to the player's identity is the one thing that was
    // never part of that job, so it stays here rather than moving into the
    // service.
    readonly property string _title: Media.titleOf(root.spotify) !== ""
        ? Media.titleOf(root.spotify)
        : (root.spotify?.identity ?? "")

    // True once Spotify exists with a track loaded, whether playing or
    // paused -- the same "still clickable for the length of its own
    // fade-out" reasoning the old `Media.available`-based version used,
    // just narrowed to one player.
    readonly property bool shown: root.spotify !== null && root.spotify.trackTitle !== ""

    // How see-through the expanded body is. Named and pulled out on its own
    // rather than buried in `card.color` below: this went through three
    // readings on the live wallpaper (opaque, then Caelus.opacitySurface,
    // then this) before landing here, and a future retune is a one-line
    // change instead of another hunt through the card.
    readonly property real bodyAlpha: 0.4

    // ── idle <-> expanded ──────────────────────────────────────
    // A HoverHandler, not a MouseArea, spanning root's own current bounds
    // (an Item's default HoverHandler target) -- whatever size that is,
    // idle footprint or full card -- so hovering either one keeps it open.
    readonly property bool _hovering: cardHover.hovered

    // Drives the body's own geometry, fill and border -- unchanged meaning
    // from the first version of this reveal. What changed is *when* it
    // flips on the way out: immediately on the way in (see
    // `on_HoveringChanged`'s true branch, left exactly as it was), only
    // after the staged collapse below has faded the content out first on
    // the way out.
    property bool _expanded: false

    // Content (title/artist/seek/transport) fading in a beat after the
    // body starts growing, and back out a beat before the body starts
    // shrinking -- the true reverse of each other, not just the same
    // binding read backwards. See the three collapse timers below for why
    // this needs to be its own property rather than a plain expression on
    // `_expanded`.
    property bool _contentReady: false

    // The idle visualizer's own visibility. False the instant a hover
    // starts (unchanged -- "the fade-in... looks nice, keep it exactly as
    // it is"), true only once the collapse sequence's body-shrink stage has
    // actually finished, not the moment it starts.
    property bool _idleReady: true

    Timer {
        id: contentReveal
        interval: 90
        onTriggered: root._contentReady = true
    }

    // Grace on the way out only: going in is immediate, so the widget never
    // feels laggy to find, but crossing its own edge on the way somewhere
    // else should not slam it shut mid-stride. Stage 1 of the collapse
    // itself once that grace elapses -- see `collapseGrace` below.
    on_HoveringChanged: {
        if (root._hovering) {
            collapseGrace.stop();
            collapseBody.stop();
            collapseIdle.stop();
            root._expanded = true;
            root._idleReady = false;
            contentReveal.restart();
        } else {
            collapseGrace.restart();
        }
    }

    Timer {
        id: collapseGrace
        interval: 300
        // Stage 1, the true reverse of the reveal's own last stage: content
        // goes first, before the body has moved at all.
        onTriggered: {
            contentReveal.stop();
            root._contentReady = false;
            collapseBody.restart();
        }
    }

    Timer {
        id: collapseBody
        // Waits out the content's own fade (Motion.fast, see `layout`'s
        // opacity Behavior below) so the body only starts shrinking once
        // there is nothing left drawn on top of it to jump.
        interval: Motion.fast
        // Stage 2: the body itself -- size, fill, border -- shrinks back
        // to the idle footprint.
        onTriggered: {
            root._expanded = false;
            collapseIdle.restart();
        }
    }

    Timer {
        id: collapseIdle
        // Waits out the body's own shrink (Motion.base, see
        // implicitWidth/Height below) so the bars only return once the
        // card has actually finished collapsing into their footprint.
        interval: Motion.base
        // Stage 3: only now do the idle bars fade back in.
        onTriggered: root._idleReady = true
    }

    // ── sizing ─────────────────────────────────────────────────
    // Fixed either way -- the card never changes width for the volume
    // control any more: DesktopTransport (see below) grows MediaVolume in
    // place, over its own transport buttons, rather than pushing the card's
    // own edge outward the way an earlier version of this card did.
    readonly property int _cardWidth: 280
    readonly property int _artSize: 56
    // CavaRing now scales its own bar length off `diameter` rather than a
    // fixed constant (see CavaRing.qml), so this pad no longer has to track
    // that number -- a fixed, generous gap between the art and the ring's
    // outer edge is enough.
    readonly property int _ringSize: root._artSize + 28

    // The idle visualizer's own footprint: bigger bars than the bar strip's
    // (see CavaBars.qml), but the same "one bar per Cava band" shape, so it
    // reads as the same instrument at a different scale rather than a new
    // one.
    readonly property int _idleBarWidth: 4
    readonly property int _idleBarSpacing: 3
    readonly property int _idleBarHeight: 32
    readonly property int _idleWidth: Cava.bars * root._idleBarWidth
        + Math.max(0, Cava.bars - 1) * root._idleBarSpacing

    implicitWidth: root._expanded ? root._cardWidth : root._idleWidth
    implicitHeight: root._expanded ? card.implicitHeight : root._idleBarHeight

    // Fades the whole widget out rather than snapping it away: Spotify
    // quitting mid-animation should read as the card leaving, not as
    // something blinking out from under the pointer.
    opacity: root.shown ? 1 : 0
    visible: root.opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: Motion.slow; easing.type: Motion.standard }
    }

    // base, not fast: Motion.qml's own "a shape changing size in place" is
    // exactly this move, just in both dimensions and a lot bigger than the
    // workspace dot it names as the example. `Motion.exit` on the way back
    // down rather than the same `standard` the grow uses -- gentle start,
    // quick finish, so the shrink reads as settling rather than as the
    // grow simply played backwards.
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Motion.base
            easing.type: root._expanded ? Motion.standard : Motion.exit
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Motion.base
            easing.type: root._expanded ? Motion.standard : Motion.exit
        }
    }

    HoverHandler {
        id: cardHover
    }

    // Turns Spotify down, not the sink -- same reasoning Media.stepVolume's
    // own comment gives, and the same notch BarLeft.qml's media pill turns
    // the wheel by. `acceptedButtons: Qt.NoButton`, the same idiom that
    // pill's own workspace-dots strip uses, so only the wheel is caught
    // here and every click still reaches whatever is underneath.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            Media.stepVolume(root.spotify, wheel.angleDelta.y > 0 ? 0.05 : -0.05);
            transport.pokeVolume();
        }
    }

    // ── idle visualizer ────────────────────────────────────────
    // The bar strip's own CavaBars, reused rather than duplicated, at a
    // bigger, non-collapsing size. `visible: true` overrides that
    // component's own default (it hides itself the instant playback
    // pauses, which is correct for the bar strip but wrong here -- this is
    // the widget's only surface while idle, and it has to stay put, resting
    // at its floor, for exactly the "paused, track loaded" case that
    // default was built to disappear for). Overriding is enough because
    // that binding is a plain property on CavaBars, not a read-only one.
    CavaBars {
        id: idleViz

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        barWidth: root._idleBarWidth
        barSpacing: root._idleBarSpacing
        barHeight: root._idleBarHeight
        // Without this the idle bars collapse to 0 width the instant
        // Spotify pauses (CavaBars.qml defaults `collapsible: true` for the
        // bar strip's own reasons) -- exactly the footprint CavaBars.qml's
        // own comment on this property says the desktop card cannot have:
        // paused-with-a-track-loaded is idle's whole reason to exist, and a
        // widget with no footprint has nothing left to hover.
        collapsible: false
        // The one caller CavaBars.qml's own `normalise` comment names: sat
        // at this size with nothing else on the card to look at, the same
        // ring-local peak normalisation CavaRing uses keeps a quiet player
        // reading as motion instead of twelve nearly-flat bars.
        normalise: true
        visible: true
        opacity: root._idleReady ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.fast
                easing.type: root._idleReady ? Motion.standard : Motion.exit
            }
        }
    }

    // ── card ───────────────────────────────────────────────────
    // Anchored to root's own bounds rather than given a size of its own:
    // root's implicitWidth/Height above are already whichever of the idle
    // footprint or the full card is current, mid-animation included, so
    // this only ever has to track its parent, never compute anything.
    Rectangle {
        id: card

        anchors.fill: parent
        radius: Caelus.radiusIsland
        implicitHeight: layout.implicitHeight + 2 * Caelus.space
        // Clips `layout` below, which is deliberately *not* sized off this
        // Rectangle's own (animating) bounds -- see the comment on
        // `layout`'s `width`. What the viewer sees is this shrinking
        // rectangle exposing less and less of a layout that never itself
        // reflows, rather than the content visibly re-wrapping as it goes.
        clip: true
        // A low, named alpha straight over the wallpaper's own colour
        // (Colors.surface, not Colors.popupBg) -- this card has no blur
        // layer rule behind it the way the popups do, so the translucency
        // has to do the work alone: Caelus.opacitySurface (0.6) still read
        // as a solid frosted slab without blur to soften it, and
        // `bodyAlpha` is the number that settled it. See `bodyAlpha` above.
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, root.bodyAlpha)
        border.width: Caelus.borderWidth
        // Transparent at rest, the shell's own accent once expanded --
        // Colors.popupAccent is Colors.accent under the name the popups use
        // (see Colors.qml) -- so hovering this card reads as *opening*,
        // not as the same idle outline merely turning visible.
        border.color: root._expanded ? Colors.popupAccent : "transparent"
        opacity: root._expanded ? 1 : 0

        Behavior on border.color {
            ColorAnimation { duration: Motion.fast }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.fast
                easing.type: root._expanded ? Motion.standard : Motion.exit
            }
        }

        RowLayout {
            id: layout

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Caelus.space
            // A fixed width, not `anchors.fill: parent`: this is the one
            // change that actually stops the collapse from reflowing --
            // tied to the card's own animating width, the title's elide
            // point and the transport row's wrapping would recompute every
            // frame of the shrink, invisibly (opacity already 0 by then)
            // but not for free, and visibly for one frame if a hover
            // interrupts the collapse mid-flight. Pinned to the card's
            // *resting* content width instead, `card`'s own `clip: true`
            // above is what actually hides the part of it that falls
            // outside the shrinking rectangle -- the content holds its
            // final layout throughout, and the body shrinks over it.
            width: root._cardWidth - 2 * Caelus.space
            spacing: Caelus.spaceSnug
            opacity: root._contentReady ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.fast
                    easing.type: root._contentReady ? Motion.standard : Motion.exit
                }
            }

            // ── art + Cava ring ──────────────────────────────
            Item {
                id: artSlot

                Layout.preferredWidth: root._ringSize
                Layout.preferredHeight: root._ringSize
                Layout.alignment: Qt.AlignVCenter

                // Only instantiated while the card is open, not just while
                // cava could run: unlike MediaPopup's ring this one lives in
                // a window that never closes, and a ring hidden under the
                // idle bars' opacity would still re-lay its ~60 spokes on
                // every cava frame, on every screen, for as long as Spotify
                // plays.
                Loader {
                    anchors.centerIn: parent
                    active: Cava.available && root._expanded
                    sourceComponent: CavaRing {
                        diameter: root._ringSize
                        tint: Colors.mediaActive
                    }
                }

                MediaArt {
                    id: art

                    anchors.centerIn: parent
                    width: root._artSize
                    height: root._artSize
                    // Bound whenever Spotify has a track loaded, idle or
                    // not -- one fetch per track change. Not gated on the
                    // hover (MediaArt's `active`): with the pixmap cache off
                    // (see MediaArt.qml for the crash that forced that),
                    // every hover would fetch the art again and open the
                    // card on the fallback glyph until it arrived.
                    source: root.shown ? (root.spotify?.trackArtUrl ?? "") : ""
                    fallbackGlyph: root.playing ? "graphic_eq" : "music_note"
                    glyphColor: root.playing ? Colors.mediaActive : Colors.mediaMeta
                }

                MouseArea {
                    anchors.fill: art
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.focusWindow(root.spotify)
                }
            }

            // ── title, artist, progress, transport ───────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Caelus.spaceTight

                // MarqueeText, not a plain elided Text: the card's own fill
                // dropped to `bodyAlpha` (see above) still needs the same
                // soft drop shadow DesktopClock.qml's bare title already
                // solved this with -- MarqueeText carries that itself, see
                // its own header. Scrolls only while the card is expanded
                // and the title overflows, resets on every track change.
                MarqueeText {
                    Layout.fillWidth: true
                    text: root._title
                    color: Colors.mediaTitle
                    pixelSize: Caelus.sizeLead
                    active: root._expanded
                }

                MediaArtists {
                    Layout.fillWidth: true
                    player: root.spotify
                    active: root._expanded
                }

                // ── seek bar ──────────────────────────────
                RowLayout {
                    id: seekRow

                    Layout.fillWidth: true
                    Layout.topMargin: Caelus.spaceTight
                    spacing: Caelus.spaceSnug

                    readonly property bool seekable: (root.spotify?.canSeek ?? false)
                        && (root.spotify?.positionSupported ?? false)
                    readonly property real fraction: (root.spotify?.length ?? 0) > 0
                        ? Math.min(1, (root.spotify?.position ?? 0) / root.spotify.length)
                        : 0

                    function seekTo(x, w) {
                        if (!seekable || !root.spotify || root.spotify.length <= 0) return;
                        root.spotify.position = Math.max(0, Math.min(1, x / w)) * root.spotify.length;
                    }

                    Text {
                        text: Format.time(root.spotify?.position ?? 0)
                        color: Colors.mediaMeta
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeLabel
                    }

                    Rectangle {
                        id: track

                        Layout.fillWidth: true
                        implicitHeight: 3
                        radius: 1.5
                        color: Colors.mediaTrack

                        Rectangle {
                            width: Math.round(track.width * seekRow.fraction)
                            height: parent.height
                            radius: parent.radius
                            color: Colors.mediaActive
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.topMargin: -8
                            anchors.bottomMargin: -8
                            enabled: seekRow.seekable
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: mouse => seekRow.seekTo(mouse.x, width)
                            onPositionChanged: mouse => {
                                if (pressed) seekRow.seekTo(mouse.x, width);
                            }
                        }
                    }

                    Text {
                        text: Format.time(root.spotify?.length ?? 0)
                        color: Colors.mediaMeta
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeLabel
                    }
                }

                // ── transport ─────────────────────────────
                // Its own file now (DesktopTransport.qml, TRANSPORT-owned):
                // the buttons-plus-volume-overlay row this used to be
                // inline got big enough, between the fade/enable pairing on
                // every button and MediaVolume's own overlay anchoring, to
                // be worth splitting out rather than reading past.
                DesktopTransport {
                    id: transport

                    Layout.fillWidth: true
                    Layout.topMargin: Caelus.spaceTight
                    player: root.spotify
                }
            }
        }
    }

    // MPRIS position does not push updates of its own -- see the
    // MprisPlayer docs. Runs only while Spotify is playing and the card is
    // shown, the same "no wakeups nobody asked for" discipline
    // Services/Cava.qml already applies to its own process.
    Timer {
        interval: 1000
        repeat: true
        running: root.shown && root.playing
        onTriggered: root.spotify?.positionChanged()
    }
}
