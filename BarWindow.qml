import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.Config

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

        // The three island rects in window coordinates, `blob`'s own input
        // (declared below alongside the three `Island` instances it reads
        // their geometry from).
        readonly property var islands: [
            { x: leftIsland.x, y: leftIsland.y, w: leftIsland.width, h: leftIsland.height },
            { x: centerIsland.x, y: centerIsland.y, w: centerIsland.width, h: centerIsland.height },
            { x: rightIsland.x, y: rightIsland.y, w: rightIsland.width, h: rightIsland.height }
        ]

        // The bar's body. Each group gets a plate *behind* it rather than being
        // wrapped inside one: wrapping would make every group's `x` island-relative
        // and quietly break all four anchor sums above, which are what aim the
        // popups at their pills. Anchored to the group it backs, so it grows and
        // shrinks with it -- the tray filling up or the mic being unplugged moves
        // the island's edge the same frame it moves the pills.
        component Island: Surface {
            id: island

            required property Item group

            anchors.fill: group
            // Only the sides are padded. The top and bottom come out of the
            // group's own height, which is one pill tall, so the island is
            // `barHeight - 2 * barInset` and the inset is real wallpaper.
            anchors.leftMargin: -Caelus.barIslandPad
            anchors.rightMargin: -Caelus.barIslandPad
            // Half of a 32px island, so the ends are semicircles. The same shape
            // the pills inside it take when hovered.
            radius: Caelus.radiusIsland
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

            Island {
                id: leftIsland
                group: leftGroup
            }

            Island {
                id: centerIsland
                group: centerGroup
            }

            Island {
                id: rightIsland
                group: rightGroup
            }

            // The fused silhouette for this screen: the three islands above, plus
            // whatever popup cards `overlays` currently reports open, drawn as one
            // shape instead of three plates and N cards each outlined by hand (see
            // the file comment atop BarPopup.qml). `z: -2` keeps it under the
            // islands (`z: -1` on the `Island` component above) and everything else
            // declared in this window, whatever order any of them end up in -- a
            // blob painted over a pill would be a much worse defect than the seam
            // it exists to remove.
            //
            // `islands` reads `bar`'s own export (declared above, before the
            // groups exist to size it from); `cards` reads `overlays.cards`,
            // built from every loaded popup's `cardRect`/`cardRadius`/`cardAlpha`
            // (BarPopup.qml) -- both are plain JS arrays already in window
            // coordinates, which is the same frame this Item and everything
            // inside it shares, so neither needs converting here.
            Blob {
                id: blob

                z: -2
                islands: bar.islands
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
            }

            BarRight {
                id: rightGroup
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
