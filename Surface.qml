import QtQuick
import QtQuick.Effects
import qs.Config

// A drop-in replacement for an island `Rectangle`, with one extra pass: a
// whisper of static grain over the fill, because compositor blur alone
// leaves a surface that looks poured rather than made -- flat, a little
// plastic, the same everywhere across three islands that are otherwise
// identical plates.
//
// The root element here is `Rectangle` itself, not an `Item` wrapping one.
// That is the only way `border.width` / `border.color` keep working
// unchanged from a call site: `property alias border: rect.border` looks
// right but the grouped property it aliases is a value object, and writing
// `Surface { border.width: 1 }` from outside reassigns through that alias
// in a way later Qt 6 minors have not reliably kept live -- it is a trap
// that only shows up when someone rebinds a colour at runtime. Being a
// Rectangle sidesteps the question entirely: `radius`, `color`, `border`
// and everything else Rectangle has are just there, exactly as a caller
// already writes them for a plain one.
Rectangle {
    id: root

    // 0 disables the pass. Not "opacity 0" -- see the Loader below, which
    // is what actually keeps `grain: 0` from instantiating anything.
    property real grain: 0

    // How strong the pass reads at `grain: 1`. Kept private and small on
    // purpose: the moment this is visible as a pattern instead of a
    // texture, it has stopped being grain. Tuned by eye against
    // Colors.barIsland at the bar's own fill opacity -- callers dial the
    // public `grain` property, they do not retune this.
    readonly property real _maxOpacity: 0.05

    // ── press feedback (opt-in) ──────────────────────────────
    // Surface is also the bar islands themselves, which the pointer crosses
    // constantly and which are not clickable -- so a Surface must never
    // light up unless something asks it to. `interactive` is that ask, off
    // by default, and everything below stays inert until it is turned on.
    property bool interactive: false
    // Surface never builds its own MouseArea: content already living inside
    // one (a pill, a row, a button) usually owns one already, and a second
    // hit area over the same rectangle would only compete with it. A caller
    // that wants the wash drives these two from whatever mouse handling it
    // already has -- e.g. `Surface { interactive: true; hovered: area.containsMouse; pressed: area.pressed }`.
    property bool hovered: false
    property bool pressed: false

    // Only built once something asks for it. `active: false` means Qt never
    // constructs the Canvas, the Image or the MultiEffect below -- not
    // "constructed but invisible" -- so `grain: 0` leaves this component
    // with exactly the scene graph a plain Rectangle has: one paint node,
    // no extra texture, no extra pass. That is what makes it free rather
    // than merely quiet.
    Loader {
        anchors.fill: parent
        active: root.grain > 0
        asynchronous: false
        sourceComponent: grainPass
    }

    // Same one-overlay, opacity-only pattern as Pill's hover wash, sized to
    // the whole surface instead of inset into it -- a Surface has no
    // "island around it" to leave a margin against. Always present rather
    // than Loader-gated like grain above: a single untextured Rectangle at
    // opacity 0 costs nothing worth guarding, and this is the same shape
    // every other rest/hover state in this shell already takes.
    Rectangle {
        id: stateLayer

        anchors.fill: parent
        radius: root.radius
        color: Colors.fg
        opacity: !root.interactive ? 0
            : root.pressed ? Caelus.opacityPress
            : root.hovered ? Caelus.opacityHover : 0

        Behavior on opacity {
            NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
        }
    }

    Component {
        id: grainPass

        Item {
            id: pass

            anchors.fill: parent
            // Inset by the border's own width so grain lands only on the
            // area the fill colour paints. Rectangle draws its border
            // stroke inside the shape's outer edge, not outside it; noise
            // reaching that far would speckle the one line meant to read
            // crisp against the wallpaper.
            anchors.margins: root.border.width
            // Concentric with the border's inner edge, not with the outer
            // radius -- otherwise the noise's own corners are a wider
            // curve than the hole the border leaves for them and a sliver
            // of square corner peeks out from under the rounding.
            readonly property real innerRadius: Math.max(0, root.radius - root.border.width)

            // A small field of grey noise, painted once. A shader would
            // redo this arithmetic 240 times a second, on three islands,
            // for a result that never changes -- there is no per-frame
            // input here for it to react to. Qt 6 ShaderEffect also needs
            // a `qsb`-compiled .frag, and this machine has neither `qsb`
            // nor `qsb6` on PATH, so that route would add a build step to
            // a repo that has never had one. Painting a tile to a Canvas
            // once and reading it back as a tiled Image costs one CPU pass
            // at startup and nothing per frame after -- the GPU is just
            // repeating a texture it already has, the same as it does for
            // any other tiled Image in this shell.
            Canvas {
                id: noise

                // Big enough that the repeat isn't itself a visible grid at
                // normal viewing distance, small enough that a pixel-by-
                // pixel fill is instant and worth doing on the GUI thread.
                width: 48
                height: 48
                // Read only as the source PNG for `tile` below, via
                // toDataURL -- this Canvas is never itself on screen.
                visible: false

                onPaint: {
                    var ctx = getContext("2d");
                    var img = ctx.createImageData(width, height);
                    // Flat white noise, alpha baked to opaque: intensity is
                    // applied once, below, as the effect's own opacity, so
                    // changing `grain` at runtime never re-triggers this
                    // paint.
                    for (var i = 0; i < img.data.length; i += 4) {
                        var v = Math.floor(Math.random() * 255);
                        img.data[i] = v;
                        img.data[i + 1] = v;
                        img.data[i + 2] = v;
                        img.data[i + 3] = 255;
                    }
                    ctx.putImageData(img, 0, 0);
                    tile.source = noise.toDataURL();
                }

                Component.onCompleted: requestPaint()
            }

            // Read only as a texture by the MultiEffect below. Opacity 0,
            // not `visible: false`: an invisible item stops producing a
            // texture entirely, the same reasoning Wallpaper.qml's reveal
            // mask and MediaPopup.qml's art backdrop spell out for their
            // own effect sources.
            Image {
                id: tile

                anchors.fill: parent
                fillMode: Image.Tile
                // Crisp texels, not a bilinear blur of them -- smoothing a
                // noise tile turns grain into soft blotches, which reads
                // as a stain rather than a texture.
                smooth: false
                mipmap: false
                cache: false
                opacity: 0
            }

            // The rounded-and-inset shape grain is allowed to touch.
            // `clip: true` only ever follows an item's bounding box in Qt
            // Quick, never its radius, so a masked MultiEffect is what
            // every rounded reveal in this shell reaches for instead.
            Item {
                id: maskShape

                anchors.fill: parent
                opacity: 0
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    radius: pass.innerRadius
                    color: "white"
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: tile
                maskEnabled: true
                maskSource: maskShape
                // The mask is a hard-edged rounded rect, white on nothing;
                // the threshold sits mid-step and the narrow spread either
                // side of it is what keeps the rounded edge from aliasing.
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.04
                // Where `grain` actually acts. Multiplying here, once, at
                // the final composite -- not by baking it into the noise
                // pixels above -- is what lets a future settings slider
                // drive this property live without ever repainting the
                // Canvas.
                opacity: root.grain * root._maxOpacity
            }
        }
    }
}
