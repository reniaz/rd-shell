pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// What the desktop looks like, for the one thing that has to match it: the bar.
//
// matugen is what turns a wallpaper into colours here, and
// scripts/wallpaper-apply.sh is what runs it; this only notices that it did.
// It returns a Material You tonal scheme, where a surface ladder and an accent
// are separate things designed to sit against each other -- not one ladder of
// a single hue, which is why pywal was dropped.
Singleton {
    id: root

    // matugen's rendering of the roles the bar consumes, or null before it
    // has ever run.
    property var material: null

    readonly property bool known: root.material !== null

    // Every role below falls back to "transparent" rather than a caelus hex
    // when matugen hasn't run: Colors.qml only reads these once `Wal.known` is
    // also true, so a real fallback colour here would be dead code that two
    // files disagree about the moment caelus.palette changes.

    readonly property color accent: root.material?.primary ?? "transparent"

    // Pushed brighter at the same saturation, so a hover state reads as "this
    // colour, lit up" rather than drifting toward a different hue.
    readonly property color accentBright: Qt.hsva(root.accent.hsvHue,
        root.accent.hsvSaturation,
        Math.min(root.accent.hsvValue * 1.2, 1.0),
        root.accent.a)

    // Saturation is pulled down as well as value pushed up here, unlike
    // accentBright: a value-only push at full saturation this high reads as
    // neon rather than as a legible tint for text or icons on a dark fill.
    readonly property color accentLight: Qt.hsva(root.accent.hsvHue,
        Math.max(root.accent.hsvSaturation - 0.25, 0),
        Math.min(root.accent.hsvValue * 1.4, 1.0),
        root.accent.a)

    // Value only, pulled down for borders and pressed states: dropping
    // saturation too would fade this toward grey instead of a darker accent.
    readonly property color accentDeep: Qt.hsva(root.accent.hsvHue,
        root.accent.hsvSaturation,
        root.accent.hsvValue * 0.6,
        root.accent.a)

    readonly property color surface: root.material?.surface ?? "transparent"

    // One step above surface -- a card resting on the bar -- and a second one
    // for hover, both read off matugen's own tonal ladder: the tones are
    // spaced perceptually, which a fixed HSV value nudge is not.
    readonly property color surfaceRaised: root.material?.surfaceContainer ?? "transparent"
    readonly property color surfaceHover: root.material?.surfaceContainerHigh ?? "transparent"

    readonly property color fg: root.material?.onSurface ?? "transparent"

    // What text or an icon needs to sit on `accent` and stay legible. Not
    // derived by hand the way accentBright/Light/Deep are: matugen's dark
    // scheme puts a light tone on primary (dark text reads), but its light
    // scheme puts a darker, more saturated one there instead (light text
    // reads) -- on_primary is matugen's own answer to that inversion, and a
    // hand-picked constant cannot get both directions right at once.
    readonly property color onPrimary: root.material?.onPrimary ?? "transparent"

    // Body and meta text's dynamic role -- matugen's own contrast-checked
    // "dimmer than onSurface" tone, and the one other role besides
    // onSurface itself that inverts correctly between light and dark scheme
    // on its own. Colors.qml's fgDim reads this; fgMuted does not need to,
    // see the comment there.
    readonly property color onSurfaceVariant: root.material?.onSurfaceVariant ?? "transparent"

    // ── semantic roles ───────────────────────────────────────
    // The three Material You roles that are *not* the accent. matugen derives
    // them from the same source colour, so they stay in the wallpaper's
    // register, but they are distinct hues rather than tones of one -- which
    // is what the pills need: four icons tinted from `primary` alone would
    // come out the same colour and stop telling you which is which.
    readonly property color secondary: root.material?.secondary ?? "transparent"
    readonly property color tertiary: root.material?.tertiary ?? "transparent"

    // Red in every Material You scheme, whatever the wallpaper is: the spec
    // pins the error role's hue near 25deg and only moves its chroma and tone.
    // That is what lets mic and power follow the palette and still read as
    // "muted" and "this ends your session".
    readonly property color error: root.material?.error ?? "transparent"

    // Keeps a colour's hue and borrows the palette's saturation and
    // brightness. A colour that carries meaning -- volume green, the chart
    // series -- cannot be replaced wholesale without deleting the meaning,
    // but it can be moved into the wallpaper's register so it stops looking
    // pasted on. Half-way, so the set keeps its own internal contrast: the
    // light and dark member of a pair converge but do not merge.
    function reshade(c) {
        if (root.material === null)
            return c;
        // Cast first. Callers pass hex string literals, and hsvHue and the
        // rest are properties of a `color` -- read off a string they are
        // `undefined`, Qt.hsva builds an invalid colour out of the NaNs, and
        // every reshaded pill renders black. Qt.darker at factor 1.0 is the
        // conversion; it returns the colour unchanged.
        const base = Qt.darker(c, 1.0);
        const ref = root.tertiary;
        return Qt.hsva(base.hsvHue,
            base.hsvSaturation + (ref.hsvSaturation - base.hsvSaturation) * 0.5,
            base.hsvValue + (ref.hsvValue - base.hsvValue) * 0.5,
            base.a);
    }

    // matugen renders this on every wallpaper change, from the template in the
    // shell's own matugen/ directory. Watched rather than read once, because
    // the whole point of the mode is that switching wallpaper recolours the
    // bar without a restart.
    FileView {
        path: `${Quickshell.env("HOME")}/.cache/rd-shell/matugen.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            // The file is rewritten in place, so a read can land on a
            // half-written copy; caught rather than left to throw, and
            // `material` keeps its last good value until the next write lands
            // whole. `primary` is checked rather than the parse alone, so a
            // JSON document that parsed but is not the shape this template
            // produces is rejected instead of leaving every role undefined.
            try {
                const parsed = JSON.parse(text());
                if (parsed && parsed.primary) root.material = parsed;
            } catch (e) {
            }
        }
        // Cleared rather than left standing, so uninstalling matugen or
        // deleting its cache drops the bar back to the caelus palette instead
        // of pinning it to the last wallpaper's colours forever.
        onLoadFailed: root.material = null
    }
}
