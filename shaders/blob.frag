// Compiled with:
//   /usr/lib64/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
//       -o shaders/blob.frag.qsb shaders/blob.frag
//
// See Blob.qml for the uniform declaration order this file's
// layout(std140) block must match exactly.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// Every uniform after qt_Opacity is a QML property on Blob.qml's
// ShaderEffect, in the same declared order -- that is how Qt Quick's
// ShaderEffect maps named `real`/`vector4d` properties onto this std140
// block (mapping is by declaration order, not by name -- verified against
// Qt 6.11.2 / Quickshell 0.3.1). Reordering a property there without
// reordering it here silently reads the wrong uniform.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 uSize;          // item size in item-local (logical) pixels
    vec4 uIsland0;        // x, y, w, h -- window/item-local pixels
    vec4 uIsland1;
    vec4 uIsland2;
    vec4 uCard0;
    vec4 uCard1;
    vec4 uCard2;
    vec4 uCard3;
    vec4 uCardRadius;    // per-card corner radius, one slot each
    vec4 uCardAlpha;     // per-card fade, one slot each -- 0 == closed
    float uIslandRadius;  // shared by all three islands: Caelus.radiusIsland
    float uK;             // smooth-min blend radius: Caelus.blobSmoothK
    vec4 uFillColor;
    vec4 uStrokeColor;
    float uStrokeWidth;
    float uJoinY;         // shadow clip line, item-local: barHeight - barInset
    vec4 uShadow;         // blurPx, verticalOffsetPx, opacity, (unused)
    float uDpr;            // Screen.devicePixelRatio, for device-pixel AA
};

// Signed distance to an axis-aligned rounded box. Positive outside, negative
// inside, zero on the boundary -- the ordinary SDF convention every formula
// below assumes.
float sdRoundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// A rect uniform is (x, y, w, h); this is the one place that turns that into
// the centred form sdRoundBox wants, so every call site below reads exactly
// like the rect it was handed.
float sdBox(vec2 p, vec4 rect, float r) {
    vec2 c = rect.xy + rect.zw * 0.5;
    return sdRoundBox(p - c, rect.zw * 0.5, r);
}

// Circular smooth-min (matches Caelestia's own, and the toolchain smoke
// test's) plus the blend weight `h` that produced it. `h` is 0 where `b`'s
// own distance dominates the mix (deep inside b, or simply the smaller of
// the two) and 1 where `a` does. Handed back rather than left inside the
// function because the fold in `main` needs it twice over: once to merge
// the geometry, and a second time, verbatim, to fade a card's *colour* in
// step with the same seam -- see the comment on `accA` below for why a
// second, independently-tuned blend would risk a colour edge and a geometry
// edge sliding out of register with each other as `k` or a card's own size
// changes.
vec2 sminh(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    float d = mix(b, a, h) - k * h * (1.0 - h);
    return vec2(d, h);
}

// Abramowitz & Stegun 7.1.26: erf to within 1.5e-7, which GLSL 440 does
// not provide itself. Only the shadow's Gaussian falloff uses it.
float erfApprox(float x) {
    float t = 1.0 / (1.0 + 0.3275911 * abs(x));
    float y = 1.0 - ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t
                      - 0.284496736) * t + 0.254829592) * t * exp(-x * x);
    return sign(x) * y;
}

// Folds one card into the running island+card union (`accD`/`accA`) and
// into the running shadow coverage, all three `inout` so the four call
// sites in `main` read as a plain unrolled loop rather than as four copies
// of this body. An array-of-vec4 loop was avoided on purpose: qsb's GLSL
// 100 es target is the strictest of the five it compiles to, and constant
// unrolling by hand is one thing that is guaranteed to survive all five
// without relying on the compiler to do it for us.
void foldCard(vec2 p, vec4 rect, float radius, float alpha,
              inout float accD, inout float accA, inout float shadowCov)
{
    // Islands never smooth into each other (see `main`, which folds them
    // with a plain `min`), but a card always smooth-mins against whatever
    // is already accumulated -- its own island, ordinarily, since that is
    // the nearest shape by construction (every card is anchored under the
    // pill it hangs from). A far-off island or a far-off sibling card
    // simply never wins this fold: `sminh` degrades to an exact `min` once
    // the two distances are more than about `k` apart (see the comment on
    // it above), so a card cannot web onto a neighbour it is not actually
    // touching without `uK` itself being large enough to bridge the gap --
    // which is exactly the failure mode Caelus.blobSmoothK's own comment
    // calls out.
    float dCard = sdBox(p, rect, radius);
    vec2 sh = sminh(accD, dCard, uK);
    accD = sh.x;

    // Reuses `sh.y` rather than deriving a second weight from `accD`/`dCard`
    // after the fact: those two distances are already consumed inside
    // `sminh`, and a fresh smoothstep computed from them out here would be
    // *a* smooth transition across the same seam, not provably *the same*
    // one -- two independent curves through the same two points are not
    // one curve, and the tiny divergence between them is exactly a doubled
    // or a stepped edge at the join, the one thing this whole shader exists
    // to not draw. Folding every card through the same accumulator in turn
    // (rather than blending all four against the islands independently and
    // averaging) is also what makes two overlapping cards -- one fading out
    // under an island while another fades in under it, the closing-plus-
    // opening overlap case -- merge into each other exactly as smoothly
    // as either one merges into its island, instead of needing a special
    // case for card-on-card.
    accA = mix(alpha, accA, sh.y);

    // The shadow is cast from this card's own box, offset down and blurred,
    // never from the merged silhouette -- BarPopup's card used to cast its
    // shadow the same way, through a `MultiEffect` reading its own source
    // texture's alpha, and that source was the card, not the island it
    // happened to be sitting against. A fillet a few pixels across is not
    // worth folding into a 12px-blur shadow's own shape; the softness
    // swallows the difference.
    // The falloff is a Gaussian's, evaluated in closed form: a box blurred
    // by a Gaussian is, across any one edge, the Gaussian's CDF -- half
    // strength exactly on the edge, fading out over `blur` px outside and
    // saturating the same distance inside. That is the profile MultiEffect
    // drew. An earlier `1 - smoothstep(0, blur, d)` started at full
    // strength right on the edge instead, which reads as a dark rim around
    // the card rather than as a shadow under it. `blur / 3` as sigma puts
    // the tail within 0.2% of zero at `blur` px, so Blob.qml's shadow
    // margin still covers all of it.
    //
    // `step(uJoinY, p.y)` is the same hard cutoff `cardClip` enforces on
    // the card's own content today (BarPopup.qml, `y: Caelus.barHeight -
    // Caelus.barInset`): nothing the blur would otherwise smear upward may
    // paint above the join line, whatever the card below it is doing.
    // Islands cast no shadow at all -- there is nothing to fold in here for
    // them, and `main` never calls this function on one.
    vec2 halfSize = rect.zw * 0.5;
    vec2 c = rect.xy + halfSize + vec2(0.0, uShadow.y);
    float dShadow = sdRoundBox(p - c, halfSize, radius);
    float sigma = max(uShadow.x, 0.001) / 3.0;
    float mask = (0.5 - 0.5 * erfApprox(dShadow / (sigma * 1.41421356))) * step(uJoinY, p.y);
    // `max`, not `+=`: two cards' shadows overlapping (the same closing-plus-
    // opening case above) must not double up into a darker patch where they
    // cross, since MultiEffect never stacked two shadows there either -- each
    // card cast its own, one per window.
    shadowCov = max(shadowCov, mask * alpha);
}

void main() {
    vec2 p = qt_TexCoord0 * uSize;

    // Islands, unioned with a plain min -- never smoothed against each
    // other. Doing that with `sminh` would round the wallpaper gap *between*
    // two islands into their fill the moment `uK` reached it -- a
    // cross-island bleed this shader must not produce, and the one thing a
    // hard `min` cannot do, by construction: it always draws the nearer
    // island's own true edge, however close `uK` lets a card's own blend
    // reach.
    float accD = min(sdBox(p, uIsland0, uIslandRadius),
                  min(sdBox(p, uIsland1, uIslandRadius),
                      sdBox(p, uIsland2, uIslandRadius)));
    // 1.0 everywhere to start: an island contributes no fade of its own, so
    // a point that never comes under a card's influence (accA left
    // untouched by every `foldCard` below -- see `sh.y` -> 1 in that
    // comment) reaches the composite below at full material, same as
    // today's islands, which have no `opacity` binding at all.
    float accA = 1.0;
    float shadowCov = 0.0;

    foldCard(p, uCard0, uCardRadius.x, uCardAlpha.x, accD, accA, shadowCov);
    foldCard(p, uCard1, uCardRadius.y, uCardAlpha.y, accD, accA, shadowCov);
    foldCard(p, uCard2, uCardRadius.z, uCardAlpha.z, accD, accA, shadowCov);
    foldCard(p, uCard3, uCardRadius.w, uCardAlpha.w, accD, accA, shadowCov);

    // Antialiasing width in *device* pixels rather than item-local ones --
    // on a HiDPI screen (uDpr > 1) one item-local unit already spans
    // several real pixels, and a smoothstep half-width fixed at "1.0" would
    // soften the edge across all of them, reading as a blurry boundary
    // instead of a crisp one at every scale but 1x. Halving is because the
    // smoothstep below is itself already symmetric around the boundary --
    // `aa` on each side of it totals one device pixel of transition, not
    // two.
    float aa = 0.5 / max(uDpr, 1.0);

    // Fill: ordinary SDF coverage, 1 strictly inside the merged boundary, 0
    // strictly outside, antialiased across the one device pixel `aa` spans.
    float fillCov = 1.0 - smoothstep(-aa, aa, accD);

    // Stroke: fill minus the same fill shrunk inward by `uStrokeWidth` --
    // i.e. exactly the band from the true boundary (accD == 0) in to
    // `accD == -uStrokeWidth`, nothing outside it and nothing past it. That
    // is where Qt paints a Rectangle's border (inward from the outer edge,
    // never centred on it) -- the same convention the old `IslandOutline.qml`
    // Shape's path math followed before this shader replaced it (see git
    // history), so the line lands on the same pixels a border, or that old
    // `IslandOutline`/`outline` Shape, painted, and the fill under it is
    // simply covered by the (opaque) stroke colour rather than needing its
    // own inner cutout.
    float innerCov = 1.0 - smoothstep(-aa, aa, accD + uStrokeWidth);
    float strokeCov = clamp(fillCov - innerCov, 0.0, 1.0);

    // The one place `accA` actually applies: both fill and stroke fade
    // together, in lockstep, wherever a card's own alpha -- not an
    // island's -- has come to dominate this point (see `foldCard`'s comment
    // on `sh.y`). An island's own row of pixels never sees `accA` move off
    // 1, whatever any card on the far side of the bar is doing.
    fillCov *= accA;
    strokeCov *= accA;

    // Straight alpha in, premultiplied alpha out -- Qt Quick's scene graph
    // expects every fragment shader to hand back premultiplied colour (RGB
    // already scaled by A), which is also what makes the three layers below
    // composite with plain "src + dst * (1 - src.a)" instead of needing a
    // separate un-premultiply/re-premultiply step between them.
    vec4 result = vec4(0.0);

    // Shadow first, furthest back -- see `foldCard`'s comment on why it is
    // cast per-card rather than from the merged shape, and why islands
    // never contribute one (none is folded into `shadowCov` for them).
    // Cut out wherever the fill is: the fill is only `opacitySurface`
    // opaque, so a shadow left under it shows through and darkens the card
    // alone -- a tone step exactly on the join line, the one place the
    // island and the card are meant to read as a single surface. MultiEffect
    // did darken the card that way, but it lived in its own window then,
    // where the step was just another seam among several.
    float shA = shadowCov * uShadow.z * (1.0 - fillCov);
    result = vec4(0.0, 0.0, 0.0, shA) + result * (1.0 - shA);

    // Fill over the shadow -- covering it everywhere the merged silhouette
    // is opaque, exactly as the card's own fill used to sit over its
    // `layer.effect` shadow, in the texture MultiEffect blurred from.
    float fA = fillCov * uFillColor.a;
    result = vec4(uFillColor.rgb * fA, fA) + result * (1.0 - fA);

    // Stroke last, over the fill -- the boundary line is drawn on top,
    // never underneath something that could paint over it. The old
    // `IslandOutline.qml` enforced the same "nothing paints over the line"
    // rule through careful z-order (see git history); this shader gets it
    // for free by drawing the stroke last.
    float sA = strokeCov * uStrokeColor.a;
    result = vec4(uStrokeColor.rgb * sA, sA) + result * (1.0 - sA);

    fragColor = result * qt_Opacity;
}
