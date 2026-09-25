import QtQuick
import qs.Config

// The bar's islands and whatever popup cards are open under them, drawn as
// one fused silhouette -- fill, boundary stroke and the open cards' own drop
// shadow -- instead of as separately-outlined rectangles held together by
// hand-fitted fillets. Replaced `IslandOutline.qml`, `BarJunction.qml` and
// BarPopup's own card fill/outline/shadow trio, all retired once this landed
// (their last revision, with the long corner-by-corner comments describing
// exactly what a fillet had to reproduce by hand, is still in git history --
// `IslandOutline.qml`'s in particular is the clearest account of the seam
// this component exists to not draw). This component gets the same result
// as an emergent property of a signed-distance smooth-min instead, so there
// is no per-corner branching anywhere in `shaders/blob.frag`. See that file
// for the actual blend math.
//
// Callers hand over plain JS arrays -- `islands`, `cards` -- rather than
// touching the shader's uniforms directly. A `ShaderEffect`'s uniform block
// is std140 and fixed-shape: Qt Quick maps named `real`/`vector4d`
// properties onto it by declaration order (verified against Qt 6.11.2 /
// Quickshell 0.3.1; an array-of-vector4d property was never proven to work
// reliably, so this sticks to fixed named slots instead), so this item
// unpacks the arrays into six fixed slots -- three islands, four cards --
// every time either one changes, and nobody outside this file has to know
// the slots exist.
Item {
    id: root

    // The shapes actually on screen right now, in the *parent's* coordinate
    // space -- window coordinates, the frame BarWindow, BarOverlays and this
    // item all share. An island or card simply absent
    // from its array is an inactive slot; `_packIslands`/`_packCards` below
    // pad the remainder out to zero-size boxes parked off-canvas rather
    // than asking the shader to branch on a count. A GPU branches badly,
    // and std140's layout is fixed-size regardless, so "how many slots are
    // actually in use" has to be encoded as geometry (a box the smooth-min
    // can never reach) rather than as a number the shader would have to
    // read and act on.
    property var islands: []   // [{x,y,w,h}, ...], <= 3
    property var cards: []     // [{x,y,w,h,r,a}, ...], <= 4

    property real k: Caelus.blobSmoothK
    property real islandRadius: Caelus.radiusIsland
    property color fillColor: Colors.barIsland
    property color strokeColor: Colors.barIslandBorder
    property real strokeWidth: Caelus.borderWidth

    // The shadow constants BarPopup's card used to render through its own
    // `MultiEffect`, before that layer was deleted in favour of this shader
    // drawing it instead. Copied here rather than derived, since this is now
    // the only place left that needs them: `blurMax: 12`, `shadowBlur: 1.0`
    // -- i.e. the full 12px reach --
    // `shadowVerticalOffset: 3`, `shadowOpacity: 0.3`. `shadowEnabled` and
    // `autoPaddingEnabled` have no shader equivalent: the first is simply
    // "this component draws a shadow at all", which is just always true
    // here since an inactive card's alpha already zeroes its contribution
    // (see `foldCard` in the shader); the second is `_margin` below, this
    // item choosing its own bounding box wide enough to hold the blur
    // rather than relying on a layer to pad itself automatically.
    readonly property real shadowBlurPx: 12
    readonly property real shadowOffsetPx: 3
    readonly property real shadowOpacity: 0.3

    // The join line: nothing above it may carry a shadow, matching
    // `cardClip`'s own clip in BarPopup.qml today (the Item the card lives
    // inside, `y: Caelus.barHeight - Caelus.barInset`) pixel for pixel. In
    // window coordinates, like every rect in `islands`/
    // `cards`; converted to this item's own local frame alongside them in
    // `_joinYLocal` below.
    property real joinY: Caelus.barHeight - Caelus.barInset

    // How far outside a shape's own box the shader can still paint:
    // whichever of the shadow's blur+offset or the smooth-min's own reach
    // is larger, plus a couple of px of antialiasing slack. A smooth-min
    // join can bulge *past* either shape's own edge by roughly `k` at the
    // seam -- the same way two soap-film circles smin'd together meet in a
    // meniscus wider than either radius alone -- so `k` belongs in this
    // margin for the same reason the shadow's own reach does: both are
    // paint that lands outside the rects the caller handed over, and the
    // bounding box has to hold all of it or the shader effect clips its own
    // output.
    readonly property real _margin: root.shadowBlurPx + root.shadowOffsetPx + root.k + 4

    // The bounding box of every active shape, in the parent's coordinate
    // space, padded by `_margin`. This item is sized and positioned to
    // exactly that box -- not to the window -- which matters because of the
    // cost involved: Qt Quick repaints every pixel of a ShaderEffect every
    // frame the scene graph decides it is dirty, and cava alone drives that
    // at 30fps, so a full-window shader would spend the whole frame budget
    // shading wallpaper. With nothing open this collapses to just the three
    // islands' own strip; a card only widens it while that card is actually
    // on screen.
    readonly property var _bounds: {
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        let any = false;
        for (const r of root.islands) {
            if (r.w <= 0 || r.h <= 0) continue;
            any = true;
            minX = Math.min(minX, r.x); minY = Math.min(minY, r.y);
            maxX = Math.max(maxX, r.x + r.w); maxY = Math.max(maxY, r.y + r.h);
        }
        for (const c of root.cards) {
            if (c.w <= 0 || c.h <= 0 || c.a <= 0) continue;
            any = true;
            minX = Math.min(minX, c.x); minY = Math.min(minY, c.y);
            maxX = Math.max(maxX, c.x + c.w); maxY = Math.max(maxY, c.y + c.h);
        }
        // Nothing active at all (every island still width/height 0, the
        // frame before BarWindow's groups have been laid out even once) --
        // collapse to an empty, zero-cost box rather than the `Infinity`s
        // above leaking into `x`/`width` and NaN-ing every binding that
        // reads them.
        if (!any) return { x: 0, y: 0, w: 0, h: 0 };
        return {
            x: minX - root._margin, y: minY - root._margin,
            w: (maxX - minX) + root._margin * 2, h: (maxY - minY) + root._margin * 2,
        };
    }

    x: root._bounds.x
    y: root._bounds.y
    width: root._bounds.w
    height: root._bounds.h

    // Everything the shader is handed is in *this item's* local pixels, not
    // the parent's -- `qt_TexCoord0 * uSize` in blob.frag walks 0..width,
    // 0..height, so a rect still expressed in parent coordinates would draw
    // `_margin` pixels off from where it should. Subtracting `root.x`/
    // `root.y` here, once, is cheaper than teaching the shader a second
    // offset pair and keeps every rect uniform simply "where this shape is
    // on screen, in the space this shader already works in".
    function _localRect(r) {
        return Qt.vector4d(r.x - root.x, r.y - root.y, r.w, r.h);
    }

    readonly property var _packedIslands: {
        const out = [];
        for (let i = 0; i < 3; i++) {
            const src = root.islands[i];
            // Off-canvas by a comfortable multiple of any plausible margin,
            // not merely "far": `sdBox` measures from this box's own
            // *centre*, so a zero-size box left at (0,0) would sit inside
            // the shader's own item and fold a phantom island into the
            // union right in the corner of the bar. Placing it a solid
            // -100000px away guarantees its distance to every real pixel
            // clears `uK` and the shadow blur by many orders of magnitude,
            // so `sminh` degrades to an exact, harmless `min` (see the
            // comment on it in blob.frag) rather than a near miss.
            out.push(src && src.w > 0 && src.h > 0
                ? root._localRect(src)
                : Qt.vector4d(-100000, -100000, 0, 0));
        }
        return out;
    }

    readonly property var _packedCards: {
        const out = [];
        for (let i = 0; i < 4; i++) {
            const src = root.cards[i];
            const active = src && src.w > 0 && src.h > 0 && src.a > 0;
            out.push({
                rect: active ? root._localRect(src) : Qt.vector4d(-100000, -100000, 0, 0),
                r: active ? src.r : 0,
                a: active ? src.a : 0,
            });
        }
        return out;
    }

    ShaderEffect {
        id: shader

        anchors.fill: parent

        // Declared in exactly the order blob.frag's uniform block expects
        // after `qt_Matrix`/`qt_Opacity` -- see the comment atop that file.
        property var uSize: Qt.point(width, height)
        property var uIsland0: root._packedIslands[0]
        property var uIsland1: root._packedIslands[1]
        property var uIsland2: root._packedIslands[2]
        property var uCard0: root._packedCards[0].rect
        property var uCard1: root._packedCards[1].rect
        property var uCard2: root._packedCards[2].rect
        property var uCard3: root._packedCards[3].rect
        property var uCardRadius: Qt.vector4d(
            root._packedCards[0].r, root._packedCards[1].r,
            root._packedCards[2].r, root._packedCards[3].r)
        property var uCardAlpha: Qt.vector4d(
            root._packedCards[0].a, root._packedCards[1].a,
            root._packedCards[2].a, root._packedCards[3].a)
        property real uIslandRadius: root.islandRadius
        // `max(0.001, ...)`: `sminh` divides by `uK`, and a caller passing
        // 0 (turning smoothing off outright, say for a debug frame) would
        // otherwise hand the shader a divide-by-zero instead of the sharp
        // butt-join "no smoothing" ought to mean. 0.001px of blend radius
        // reads as no blend at all to a screen.
        property real uK: Math.max(0.001, root.k)
        property var uFillColor: Qt.vector4d(root.fillColor.r, root.fillColor.g, root.fillColor.b, root.fillColor.a)
        property var uStrokeColor: Qt.vector4d(root.strokeColor.r, root.strokeColor.g, root.strokeColor.b, root.strokeColor.a)
        property real uStrokeWidth: root.strokeWidth
        property real uJoinY: root.joinY - root.y
        property var uShadow: Qt.vector4d(root.shadowBlurPx, root.shadowOffsetPx, root.shadowOpacity, 0)
        // `Screen` is an attached type, only reachable through an Item
        // that is actually inside a window -- reading it on `root` itself
        // rather than on this `ShaderEffect` makes no difference (both are
        // in the same window), but matches where every other screen-aware
        // read in this codebase attaches it. Falls back to 1 while this
        // item has not been parented into a window yet (Screen.
        // devicePixelRatio is 0 before that), which keeps the antialiasing
        // width in blob.frag sane rather than dividing by zero on the
        // first frame.
        property real uDpr: root.Screen.devicePixelRatio > 0 ? root.Screen.devicePixelRatio : 1

        fragmentShader: Qt.resolvedUrl("shaders/blob.frag.qsb")
    }
}
