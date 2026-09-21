pragma Singleton
import Quickshell
import QtQuick

// The "caelus" palette, transcribed as hex literals from
// ~/coding/palette/caelus.palette. That file is the source of truth for the
// role each colour plays -- read it before touching a value here. This
// singleton exists only for the wallpaper switcher: Colors.qml already carries
// the bar's own palette (pywal-driven, so it follows the wallpaper), and the
// switcher wants the fixed theme underneath instead, since it is the one piece
// of chrome that must stay legible no matter which wallpaper it is choosing.
Singleton {
    id: root

    // ── neutral ladder ───────────────────────────────────────
    // Darkest to lightest; going up a step means "closer to the reader".
    readonly property color base: "#1e1f1e"       // the background
    readonly property color surface: "#272a28"    // a panel or card on the base
    readonly property color elevated: "#2e322f"   // a card on a panel
    readonly property color border: "#3b403c"     // 1px lines, input outlines
    readonly property color element: "#3b403c"    // a button or input at rest
    readonly property color elementActive: "#4a4f4b" // that element hovered/selected
    // The palette writes this one RGBA, #1e1f1e at cc alpha. Qt reads an
    // 8-digit hex colour as #AARRGGBB, not #RRGGBBAA, so transcribed verbatim
    // it came out as a 12%-alpha blue and the scrim was invisible. Reordered
    // here rather than in the palette file, which is not Qt's to read.
    readonly property color overlay: "#cc1e1f1e" // scrim behind a modal

    // ── text ─────────────────────────────────────────────────
    readonly property color textBright: "#f8f5f2" // 15.2:1 -- headings
    readonly property color textPrimary: "#baa89a" //  7.2:1 -- body
    readonly property color textMuted: "#72746a"  //  3.5:1 -- labels, captions
    readonly property color textSubtle: "#4d5652" //  2.2:1 -- placeholders only

    // ── accent ───────────────────────────────────────────────
    // One accent per screen. `accent` is for fills and large shapes; small
    // accent text uses `accentBright` instead, since `accent` is only 4.2:1 and
    // fails AA below 18px.
    readonly property color accent: "#b86e38"
    readonly property color accentBright: "#ef934d"
    readonly property color accentDeep: "#d76e1d"
    readonly property color accentLight: "#f8ccab"
    // Not `onAccent`: QML reads any `on<Capital>` identifier as a signal
    // handler (it would parse this as a handler for a signal named `accent`),
    // so the property that answers "what goes on top of the accent" needs a
    // name that does not collide with that syntax.
    readonly property color textOnAccent: "#000000"

    // ── shape ────────────────────────────────────────────────
    readonly property int radiusCard: 8
    readonly property int radiusPopover: 12
    readonly property int borderWidth: 1

    // ── type ─────────────────────────────────────────────────
    // Single families, not lists: Qt 6.11's QML `font` value type registers no
    // `families` property (the Quick plugin exposes letterSpacing, styleName
    // and variableAxes, but nothing for a family list), so a fallback chain
    // cannot be written here. Where caelusevka has no glyph, Qt falls through
    // to whatever fontconfig nominates; naming CaskaydiaCove as that fallback
    // is a fontconfig rule, not a shell setting.
    readonly property string fontFamily: "caelusevka"
    readonly property string symbolFamily: "Material Symbols Rounded"

    readonly property int sizeLabel: 12
    readonly property int sizeBody: 13
    readonly property int sizeLead: 15
    readonly property int sizeTitle: 18
}
