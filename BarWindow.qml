import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.Config
import qs.Services

// The per-screen window host. The bar strip and every popup it opens used
// to each be their own PanelWindow; they are fused into one surface here so
// a popup's card and the island it hangs off can be drawn as one silhouette
// with no seam between two windows' worth of pixels -- `blob` below (see
// its own comment, further down) is what actually draws that silhouette,
// in place of the per-corner `BarJunction` fillets an earlier bar used to
// hand-fit for the same effect.
//
// wlr-layer-shell will not honour a positive exclusiveZone on a surface
// anchored to all four edges -- it comes back as either 0 or the surface's
// own full height, neither of which is the 44px this bar has always
// reserved -- so reservation is split into its own tiny sibling window,
// the way caelestia-shell does it
// (~/coding/caelestia-shell/modules/drawers/Exclusions.qml): invisible,
// anchored to the strip alone, telling the compositor to hold that space
// open. The fused window below sets `exclusionMode: ExclusionMode.Ignore`
// so it does not also try to claim (or fight over) that same 44px.
Scope {
    id: root

    required property var modelData

    // Reserves the 44px strip and nothing else. `mask: Region {}` is an
    // empty region, so this window is invisible to the pointer as well as
    // to the eye -- its only job is the number in exclusiveZone. A separate
    // namespace keeps it out of the blur rule that matches the fused
    // window below (see hyprland.lua's quickshell-blur rule, which matches
    // by namespace).
    PanelWindow {
        id: exclusion

        screen: root.modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: 1
        exclusiveZone: Caelus.barHeight
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "qs-bar-exclusion"
    }

    // The fused surface: bar strip, islands, and every popup that used to be
    // its own window -- nine of them, all now `Item`s parented under
    // `overlays` below. Anchored to all four edges so a card opening under
    // any island -- however far down the screen it grows -- is still inside
    // this same surface. Layer is WlrLayer.Top, the bar's own layer today;
    // the nine popups move down from Overlay to Top with it, which is safe
    // because nothing in this shell relies on a popup sitting above another
    // Top-layer surface.
    PanelWindow {
        id: bar

        screen: root.modelData
        anchors { top: true; left: true; right: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        // Namespace deliberately left unset: it defaults to Quickshell's own
        // "quickshell", already the match hl.layer_rule uses for
        // whole-window blur today. The old per-popup namespaces this window
        // absorbs (qs-audio, qs-calendar, ...) are retired with them; what
        // remains is trimming hyprland.lua's second, per-popup blur rule
        // down to only the namespaces that still exist as separate windows.
        WlrLayershell.keyboardFocus: overlays.anyPopupOpen
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        // The window itself paints only this background colour (transparent
        // today). It is now anchored to all four edges -- the whole
        // screen -- rather than just the 44px the compositor actually
        // reserves for it (that reservation still comes from `exclusion`
        // above, sized off `Caelus.barHeight`), so that a popup card opening
        // below the strip stays inside this same surface. What reads as
        // "the bar" is the three islands inside `strip`, pinned to the top
        // of this window (see the comment on `strip`, below).
        color: Colors.barBg

        Behavior on color { ColorAnimation { duration: Motion.slow } }

        // Closed: only the bar strip blocks the pointer, exactly like
        // today's per-window Bar.qml, which sets no mask at all and so
        // blocks its own *whole* implicit height across the *whole*
        // width -- gaps between islands included, not just the islands
        // themselves. `barOnlyMask` reproduces that on a window that is
        // now full-screen rather than 44px tall, so nothing below the
        // strip is accidentally made to eat clicks it never used to.
        // Open: null, meaning the whole surface -- so a click anywhere,
        // including below the strip wherever the popup's own card did not
        // reach, lands on that popup's backdrop MouseArea (BarPopup.qml)
        // instead of passing through to whatever is under this window.
        mask: overlays.anyPopupOpen ? null : barOnlyMask

        Region {
            id: barOnlyMask
            x: 0
            y: 0
            width: bar.width
            height: Caelus.barHeight
        }

        // leftGroup sits in `strip`, which sits at the window's origin, so
        // its x plus the pill's is already window-relative and stays live
        // as the workspace dots beside it change width.
        readonly property real systemAnchorX: leftGroup.x + leftGroup.systemAnchorX
        readonly property real mediaAnchorX: leftGroup.x + leftGroup.mediaAnchorX

        // centerGroup is centred in the window rather than laid out from an
        // edge, but `strip` spans the window from its origin, so its x needs
        // no conversion either.
        readonly property real clockAnchorX: centerGroup.x + centerGroup.clockAnchorX

        // rightGroup is laid out from the far edge of the same full-width `strip`,
        // so the same sum holds. Named here rather than written out at the loader,
        // the way the disk and volume popups still do it, because the network pill
        // has pills on both sides of it that come and go -- the tray appearing and
        // the mic being unplugged each move it, and this keeps that in one place.
        readonly property real networkAnchorX: rightGroup.x + rightGroup.networkAnchorX

        // Which style the shapes below have actually *finished* arriving
        // at. Deliberately not a binding on `BarStyles.current`: that
        // property already holds the *new* id by the time anything reacts
        // to it changing (Qt's own change signals always fire after the
        // write), so reading it here would make "the style just left"
        // indistinguishable from "the style just picked" the instant a
        // switch happens. Written only from `morphAnim.onFinished`, below --
        // see the comment there for what that buys a second switch that
        // arrives before the first has landed.
        property string _activeStyle: ""

        Component.onCompleted: bar._activeStyle = BarStyles.current

        // The pad-inset rect a pill group sits inside, in window
        // coordinates -- what the old `Island { anchors.fill: group;
        // anchors.leftMargin: -Caelus.barIslandPad; anchors.rightMargin:
        // -Caelus.barIslandPad }` pairing produced by construction, before
        // any style had a say in it. Pulled out as its own function because
        // `_styleShapes` below needs to build it three times over for
        // whichever style it is asked for -- "islands" *is* these three
        // rects, verbatim; "full" only starts from them, to find where to
        // cut the strip.
        function _groupRect(group) {
            return {
                x: group.x - Caelus.barIslandPad,
                y: group.y,
                w: group.width + Caelus.barIslandPad * 2,
                h: group.height
            };
        }

        // How far past the top, left and right screen edges `full`'s strip
        // is pushed -- comfortably past both the corner radius a style
        // starts from (Caelus.radiusIsland) and the extra reach a card's
        // own smooth-min join can add on top of that (Caelus.blobSmoothK,
        // see the comment on Blob's own `_margin`), so neither one ever
        // lands back inside the visible window. Only the bottom edge --
        // the strip's real boundary, held at `Caelus.barHeight` -- is ever
        // meant to read as a line.
        readonly property real _offEdge: Caelus.radiusIsland + Caelus.blobSmoothK + 32

        // The blob geometry a style wants right now: three island rects in
        // window coordinates, plus the one corner radius they all share
        // (Blob draws every island at a single `islandRadius` -- see the
        // comment on that property in Blob.qml, and the task that left it
        // that way). Built off `leftGroup`/`centerGroup`/`rightGroup`'s own
        // live layout -- everything read in here, directly or through
        // `_groupRect`, is a plain QML property, so a caller reading
        // `_styleShapes(...)` from inside a binding gets the tray filling
        // up, the mic being unplugged, or a workspace appearing for free,
        // in whichever style asked for it.
        //
        // This is the function BarStyles.qml's header comment names as one
        // of the three edit points a new style takes. An id this ladder
        // does not recognise falls back to "islands" -- the same fallback
        // `BarStyles.current` itself already gives a stale or typo'd
        // settings.json value -- so this is never reached with nothing to
        // draw.
        function _styleShapes(id) {
            const raw = [
                bar._groupRect(leftGroup),
                bar._groupRect(centerGroup),
                bar._groupRect(rightGroup)
            ];

            if (id === "full") {
                // One flush strip, still reported as three rects rather
                // than one: that is what lets the grain Surfaces below --
                // one per rect, same as `islands` -- keep tracking
                // whichever pill group is moving even while the bar reads
                // as a single edge-to-edge plate. Partitioned at the
                // midpoints between the live islands, so `islands` below
                // (what those Surfaces actually render) always meets with
                // no gap and no overlap.
                const off = bar._offEdge;
                const top = -off;
                const height = Caelus.barHeight - top;
                const midLC = (raw[0].x + raw[0].w + raw[1].x) / 2;
                const midCR = (raw[1].x + raw[1].w + raw[2].x) / 2;
                const islands = [
                    { x: -off, y: top, w: midLC + off, h: height },
                    { x: midLC, y: top, w: midCR - midLC, h: height },
                    { x: midCR, y: top, w: bar.width + off - midCR, h: height }
                ];

                // What `blob` is actually handed: the same three segments,
                // each widened by `off` into whichever neighbour it meets.
                // Two boxes that only *touch* still each report their own
                // edge as a zero-distance boundary to blob.frag's SDF --
                // `min(d0, d1)` at the exact seam is `min(0, 0)`, not the
                // deeply-negative "obviously interior" value either box
                // alone would give a pixel either side of it -- so the
                // stroke pass (which paints wherever the merged distance
                // is within `uStrokeWidth` of 0) reads that seam as a real
                // edge and draws a sliver of border colour right down it.
                // Overlapping by `off` -- the same margin already proven
                // to clear the union's *outer* corner and blend reach, see
                // the comment on it above -- pushes every internal seam
                // deep inside whichever segment is winning the union
                // there, far past the 1px stroke ever reaches, so `min`
                // folds the three into one rect with no interior line
                // instead of three rects outlined at their own edges.
                // `islands` above is left at the exact partition on
                // purpose: a Surface's grain pass has no SDF to leak a
                // seam from, and giving it the same overlap would just
                // double the grain's already-subtle opacity across every
                // band two segments now share.
                const blobIslands = [
                    { x: islands[0].x, y: top, w: islands[0].w + off, h: height },
                    { x: islands[1].x - off, y: top, w: islands[1].w + off * 2, h: height },
                    { x: islands[2].x - off, y: top, w: islands[2].w + off, h: height }
                ];

                return { radius: 0, islands, blobIslands };
            }

            if (id === "corners") {
                // Left island unchanged. The right island is centre (the
                // clock group) docked against the right group's own left
                // edge and merged with it -- BarCenter.qml's `dockRight`
                // anchors the two flush in this style (see the comment
                // there), so `raw[1]`/`raw[2]` already sit edge to edge
                // here and this only needs their bounding-box union, not a
                // gap-aware merge. The third slot is not a pill group at
                // all: it is the notch tab, centred on the bar's own
                // width and sized off Dashboard.tabWidth, flush with the
                // real top screen edge via the same `_offEdge` push `full`
                // uses above -- see that branch's comment for why a
                // rect's top edge has to land outside the visible window
                // rather than merely at its y origin for a flush edge to
                // read as one. Its *visible* height (from the real y 0
                // down to the rect's own bottom) is deliberately shorter
                // than the corner islands', rather than the full
                // Caelus.barHeight: a tab, unlike an island, holds no
                // pills to clear, only a small glyph.
                const cL = raw[1], cR = raw[2];
                const rightX = Math.min(cL.x, cR.x);
                const rightEdge = Math.max(cL.x + cL.w, cR.x + cR.w);
                const right = {
                    x: rightX,
                    y: Math.min(cL.y, cR.y),
                    w: rightEdge - rightX,
                    h: Math.max(cL.h, cR.h)
                };

                const off = bar._offEdge;
                const tabW = Dashboard.tabWidth;
                // While the dashboard is open the tab grows the last
                // `barInset` down to the islands' own bottom edge -- the
                // y (Blob.joinY) every popup card starts at -- so the card
                // meets it edge to edge and Blob's smooth-min draws the
                // concave flare there, below the bar's y-range, the same
                // way it fuses the calendar onto the clock island. Left
                // short, the card would float a gap below it unjoined.
                const tabShortH = Math.max(1, raw[0].h - Caelus.barInset);
                const tabFullH = raw[0].y + raw[0].h;
                const tabVisibleH = tabShortH + (tabFullH - tabShortH) * bar._notchDrop;
                const tab = {
                    x: (bar.width - tabW) / 2,
                    y: -off,
                    w: tabW,
                    h: tabVisibleH + off
                };

                const islands = [raw[0], right, tab];
                // Not widened into each other the way `full`'s
                // `blobIslands` are: these three stay genuinely separate
                // plates with real gaps between them, same as `islands`
                // style, so no seam-avoidance margin is needed here.
                return { radius: Caelus.radiusIsland, islands, blobIslands: islands };
            }

            return { radius: Caelus.radiusIsland, islands: raw, blobIslands: raw };
        }

        // 0 with the dashboard closed, 1 with it open -- eased on the
        // same Motion.spatial pairing the card's own reveal uses, so the
        // notch tab's drop to the card's join line lands with the card
        // instead of snapping a frame ahead of it.
        property real _notchDrop: Dashboard.open && BarStyles.current === "corners" ? 1 : 0
        Behavior on _notchDrop {
            NumberAnimation {
                duration: Motion.spatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Motion.spatialCurve
            }
        }

        // `_activeStyle`'s own shapes (wherever the last completed
        // transition actually landed) and `BarStyles.current`'s (wherever
        // it is headed now) -- both fully live, so both ends of a morph
        // keep tracking pill geometry even while `_morphT` is mid-flight
        // between them, exactly like a settled style already does.
        readonly property var _fromShape: bar._styleShapes(bar._activeStyle)
        readonly property var _toShape: bar._styleShapes(BarStyles.current)

        // 0 at the start of a switch, 1 once it has arrived. `morphAnim`
        // below is the only thing that ever writes this, on
        // Motion.spatial/spatialCurve -- the same pairing a popup extrudes
        // on -- so a style switch reads with the same weight: the islands
        // grow into the strip, or shrink back out of it, rather than
        // cutting.
        property real _morphT: 1

        // What `blob` and the three grain Surfaces below actually draw --
        // `_fromShape` and `_toShape` blended by `_morphT`, recomputed
        // every time any of the three changes. Generic over however many
        // islands or styles exist: nothing here branches on a style id,
        // only `_styleShapes` above does that.
        readonly property var _shape: bar._lerpShape(bar._fromShape, bar._toShape, bar._morphT)

        function _lerpShape(a, b, t) {
            const lerp = (x, y) => x + (y - x) * t;
            const lerpRects = (arrA, arrB) => {
                const out = [];
                for (let i = 0; i < 3; i++) {
                    const ra = arrA[i], rb = arrB[i];
                    out.push({
                        x: lerp(ra.x, rb.x), y: lerp(ra.y, rb.y),
                        w: lerp(ra.w, rb.w), h: lerp(ra.h, rb.h)
                    });
                }
                return out;
            };
            // Radius floored at 0: `spatialCurve` overshoots slightly past
            // its own endpoint on the way to settling (see the comment on
            // it in Motion.qml), and a corner radius that briefly goes
            // negative is undefined for Blob's `sdRoundBox` in a way a
            // rect that briefly overshoots its own final size simply is
            // not.
            return {
                radius: Math.max(0, lerp(a.radius, b.radius)),
                islands: lerpRects(a.islands, b.islands),
                blobIslands: lerpRects(a.blobIslands, b.blobIslands)
            };
        }

        NumberAnimation {
            id: morphAnim
            target: bar
            property: "_morphT"
            to: 1
            duration: Motion.spatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Motion.spatialCurve
            // Only a transition that actually reaches its target settles
            // `_activeStyle` -- `restart()` below interrupting one
            // mid-flight stops it instead of finishing it, which never
            // fires this, so a second switch arriving before the first has
            // landed keeps morphing from the last style that really did
            // settle rather than snapping to whatever the interrupted one
            // had reached by then.
            onFinished: bar._activeStyle = BarStyles.current
        }

        Connections {
            target: BarStyles

            function onCurrentChanged() {
                // settings.json is read after the bar is already built, so the
                // saved style arriving at startup is not a switch anyone made
                // -- take it as it is rather than morphing into it on every
                // shell start.
                if (!Settings.ready) {
                    morphAnim.stop();
                    bar._activeStyle = BarStyles.current;
                    bar._morphT = 1;
                    return;
                }
                bar._morphT = 0;
                morphAnim.restart();
            }
        }

        // The bar's body. Each group gets a plate *behind* it rather than being
        // wrapped inside one: wrapping would make every group's `x` island-relative
        // and quietly break all four anchor sums above, which are what aim the
        // popups at their pills. Positioned off `_shape.islands[index]` rather
        // than anchored to the group it used to sit behind: at rest in
        // "islands" style that is the exact same rect (`_styleShapes` builds
        // it from the same `_groupRect` math the old `anchors.fill` +
        // margins pair produced), but the plate also has to become a third
        // of an edge-to-edge strip in "full" and everything in between --
        // geometry `_shape` already tracks for `blob` below, so this reads
        // it straight off the same source rather than growing a second,
        // independently-drifting copy of the same morph.
        component IslandSurface: Surface {
            id: island

            required property int index

            readonly property var _rect: bar._shape.islands[island.index]

            x: island._rect.x
            y: island._rect.y
            width: island._rect.w
            height: island._rect.h
            radius: bar._shape.radius
            // Transparent: `blob` below draws the island's fill, in the same
            // pass as its stroke and every open card, so this Surface paints
            // nothing of its own material any more -- see the comment on
            // `blob` for why one shape drawn once replaced three drawn
            // separately and hand-fitted at the seams.
            color: "transparent"
            // Zero always. Surface insets its grain pass by this width (see
            // Surface.qml around lines 90-100), and a zero inset is what lets
            // the grain reach all the way to the island's own boundary and
            // round at its own radius, rather than sitting a pixel short of
            // the line `blob` now draws there.
            border.width: 0
            // Compositor blur alone leaves a plate looking like moulded plastic.
            // A static noise tile at a twentieth of full strength is the whole
            // difference between a surface and a fill; at this intensity it is
            // not visible as grain, only as the plate having a material.
            grain: 1
            // Behind the pills whatever the declaration order happens to be,
            // and behind `blob` too (see its own `z`, well below this).
            z: -1
        }

        // The bar's own 44px, pinned to the top of a window that is now the
        // whole screen. Bar.qml's window was exactly this tall, so the groups'
        // `anchors.verticalCenter: parent.verticalCenter` put them in the bar;
        // parented straight to this full-screen window, the same anchor put
        // them -- and the islands that fill them -- halfway down the monitor.
        // At x 0, y 0, so everything inside still reads window coordinates:
        // the anchor sums above and `islands` need no conversion.
        Item {
            id: strip

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Caelus.barHeight

            IslandSurface {
                index: 0
            }

            IslandSurface {
                index: 1
            }

            IslandSurface {
                index: 2
            }

            // The fused silhouette for this screen: the three islands above, plus
            // whatever popup cards `overlays` currently reports open, drawn as one
            // shape instead of three plates and N cards each outlined by hand (see
            // the file comment atop BarPopup.qml). `z: -2` keeps it under the
            // islands (`z: -1` on the `IslandSurface` component above) and
            // everything else declared in this window, whatever order any of them
            // end up in -- a blob painted over a pill would be a much worse defect
            // than the seam it exists to remove.
            //
            // `islands`/`islandRadius` read `bar._shape` -- the active style's
            // geometry, mid-morph or settled (see the comment on `_shape`,
            // above). `islands` specifically reads `blobIslands`, not the
            // exact-partition rects the grain Surfaces above render -- see
            // the comment on that second array, in `_styleShapes`, for the
            // seam it exists to keep out of the shader's stroke pass.
            // `cards` reads `overlays.cards`, built from every loaded
            // popup's `cardRect`/`cardRadius`/`cardAlpha` (BarPopup.qml) --
            // all already plain JS data in window coordinates, the same
            // frame this Item and everything inside it shares, so nothing
            // here needs converting.
            Blob {
                id: blob

                z: -2
                islands: bar._shape.blobIslands
                islandRadius: bar._shape.radius
                cards: overlays.cards
            }

            BarLeft {
                id: leftGroup
                // `bar` (the PanelWindow) has no `modelData` property of its own
                // -- only the outer Scope does, since that is what Variants in
                // shell.qml sets -- so this reaches past it to `root`.
                modelData: root.modelData
            }

            BarCenter {
                id: centerGroup
                // Only in "corners": BarCenter.qml's own `dockRight` swaps
                // its centreIn for an anchor against this item's left edge
                // when set (see the comment there), so the clock group
                // reads as part of the same right-hand island as
                // `rightGroup` rather than floating alone in the middle.
                // Null the rest of the time, which is the property's own
                // default and what keeps every other style's centring
                // untouched.
                dockRight: BarStyles.current === "corners" ? rightGroup : null
            }

            BarRight {
                id: rightGroup
            }

            // The notch tab: idea corner-islands-notch-dashboard's third
            // island, and the only thing in `strip` that is not a pill
            // group. Positioned straight off `_styleShapes`'s own "corners"
            // geometry rather than growing a second copy of that math --
            // `_rect` tracks the live morph the same way `IslandSurface`
            // does, so the clickable area and the glyph always sit exactly
            // where the Blob plate they are drawn over actually is.
            // `y`/`height` only take the rect's *visible* span (from the
            // real top edge down to its bottom) rather than its off-screen
            // top -- the plate itself is pushed past y 0 by `_offEdge` so
            // its own top edge never draws a border line (see the
            // `_styleShapes` comment), but a MouseArea has no such edge to
            // hide and only needs to cover the pixels someone can actually
            // see and click.
            Item {
                id: notchTab

                // Only drawn/clickable while this style is actually
                // settled on "corners" -- not merely morphing through it
                // from a neighbour, the same gate `bar._activeStyle`
                // exists for elsewhere in this file. Instant rather than
                // faded: every other conditionally-shown pill in this bar
                // (the media pill's `visible: Media.available`, say)
                // appears and disappears the same way, and the plate
                // underneath it keeps morphing regardless since `Blob`
                // reads `bar._shape` directly, not this item's visibility.
                visible: BarStyles.current === "corners"

                readonly property var _rect: bar._shape.islands[2]
                readonly property bool hovered: tabArea.containsMouse
                readonly property bool pressed: tabArea.pressed

                x: notchTab._rect.x
                y: 0
                width: notchTab._rect.w
                height: Math.max(0, notchTab._rect.y + notchTab._rect.h)

                Rectangle {
                    id: tabHoverWash

                    anchors.fill: parent
                    anchors.topMargin: Caelus.spaceTight
                    anchors.bottomMargin: Caelus.spaceTight
                    radius: Caelus.radiusPill
                    color: Colors.fg
                    // Same rest/hover/press shape as Pill.qml's own
                    // `hoverBg` -- one Rectangle, driven by opacity alone,
                    // so this reads as the same kind of control as every
                    // pill beside it rather than a bespoke button.
                    opacity: notchTab.pressed ? Caelus.opacityPress
                        : notchTab.hovered ? Caelus.opacityHover : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "expand_more"
                    font.family: Caelus.symbolFamily
                    font.pixelSize: Caelus.sizeBody
                    color: Colors.fgMuted
                    // Points at whichever way the panel is about to go --
                    // down to open, back up to close -- the same chevron-
                    // flip idiom KeybindOverview/CalendarPopup already use
                    // for their own expanders.
                    rotation: Dashboard.open ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
                    }
                }

                MouseArea {
                    id: tabArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Dashboard.toggle()
                }
            }
        }

        // Only the bar on the focused monitor renders the overlay, so a keybind press
        // opens it where you are looking and two screens never fight over the keyboard.
        // Compared by name with a fallback: Hyprland.focusedMonitor can be unresolved
        // right after a config reload, and without the fallback the menu would silently
        // refuse to open on any screen.
        // Sticky, not a live binding. Every overlay gated on this one takes the
        // keyboard exclusively, and while a layer surface holds it Hyprland can
        // report no focused monitor at all -- which made the binding go empty a
        // frame after the overlay mapped and tore it straight back down again.
        // The last screen that really was focused is the right answer until
        // another one really is.
        property string overlayScreen: Hyprland.focusedMonitor?.name
            ?? Quickshell.screens[0]?.name
            ?? ""

        Connections {
            target: Hyprland

            function onFocusedMonitorChanged() {
                const name = Hyprland.focusedMonitor?.name ?? "";
                if (name !== "")
                    bar.overlayScreen = name;
            }
        }

        // The volume/mic OSD pulse Audio.qml itself never raises as an event; see
        // the comment in BarOsdWatch.qml for why it lives here instead.
        BarOsdWatch {
            id: volumeOsdWatch
        }

        // BarOverlays is what fills the fused window's content above the bar
        // groups: every popup it loads through PopupLoader is an Item now,
        // not a window of its own, so it needs a real visual parent sized to
        // the whole surface to sit inside -- anchors.fill does that, and
        // being declared last here is what puts it above the islands and
        // pills in z without needing one set by hand.
        BarOverlays {
            id: overlays

            anchors.fill: parent

            modelData: root.modelData
            overlayScreen: bar.overlayScreen
            systemAnchorX: bar.systemAnchorX
            mediaAnchorX: bar.mediaAnchorX
            clockAnchorX: bar.clockAnchorX
            networkAnchorX: bar.networkAnchorX
            leftGroup: leftGroup
            centerGroup: centerGroup
            rightGroup: rightGroup
            osdWatch: volumeOsdWatch
        }
    }
}
