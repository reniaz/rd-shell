pragma Singleton
import Quickshell
import QtQuick
import qs.Services

// The fixed "caelus" theme, and the shell's design tokens.
//
// The colours are transcribed as hex literals from
// ~/coding/palette/caelus.palette. That file is the source of truth for the
// role each colour plays -- read it before touching a value here. They are
// deliberately not the bar's palette: Colors.qml carries that one, and it
// follows the wallpaper, while the wallpaper switcher wants the fixed theme
// underneath instead, since it is the one piece of chrome that must stay
// legible no matter which wallpaper it is choosing.
//
// Everything below the colours -- shape, spacing, type, bar geometry -- is not
// theme but measurement, and applies everywhere. A literal repeated across
// forty files is a value nobody can change; naming it here is what makes a
// restyle one edit instead of a sweep. Motion.qml holds the same idea for
// durations and easings.
Singleton {
    id: root

    // ── theming mode ─────────────────────────────────────────
    // Flip to true and save to make Colors.qml follow the wallpaper instead
    // of this fixed caelus palette -- Quickshell hot-reloads QML, so the bar
    // repaints immediately, no restart. Colors.qml gates the switch on
    // Wal.known too, so turning this on before matugen has ever run leaves the
    // bar exactly as it is rather than going blank. Off is the safe default:
    // whoever changes nothing keeps today's bar, transcribed from
    // ~/coding/palette/caelus.palette, and flipping this back to false is the
    // whole revert.
    //
    // Settings.qml is the live control once it exists on disk -- a
    // settings.json means someone opened that panel and made a
    // choice, and every line below starts deferring to it. `typeof` guards
    // the reference rather than reading `Settings.dynamicColour` straight:
    // that identifier only resolves once Services/Settings.qml has actually
    // landed in the tree, and this file has to keep compiling and starting
    // the bar correctly both before that file exists and before its JSON has
    // ever been written -- Settings.qml's own JsonAdapter default is the
    // same `true`/"tonal-spot" this file falls back to, so the two agree
    // either way. scripts/wallpaper-apply.sh reads `scheme` with the exact
    // same precedence, so the shell script and the QML it recolours never
    // disagree about which one is live.
    readonly property bool dynamicColour: typeof Settings !== "undefined" ? Settings.dynamicColour : true

    // matugen's `-t/--type scheme-<name>`. One of: tonal-spot, content,
    // expressive, fidelity, vibrant, neutral, monochrome, rainbow,
    // fruit-salad -- checked against this machine's matugen 4.2.0
    // (`matugen --help`) rather than assumed; matugen also has scheme-smart
    // (auto-picks a scheme from the source colour), left off this list
    // because it was not one of the named schemes the roadmap asked for.
    // Fixed. The shell shipped a ten-chip scheme picker for a while and the
    // answer was tonal-spot every time -- it is the scheme Material You itself
    // defaults to, and the only one that reliably produces a usable neutral
    // surface ramp from an arbitrary wallpaper. The others are kept reachable
    // by editing this line rather than by a control nobody moved twice. The
    // settings popup's "Wallpaper colours" toggle is the one exception: it
    // is a binary on/off, not a picker, and when on, scripts/matugen-scheme.sh
    // overrides this line's answer -- normally to `content`, which keeps a
    // wallpaper's own colours instead of inventing a secondary/tertiary hue,
    // or to `monochrome` (white/grey, no hue at all) when the wallpaper
    // itself has no real colour to keep, so an achromatic wallpaper doesn't
    // quietly pick up matugen's own blue fallback instead. Config/Caelus.qml
    // itself stays fixed at tonal-spot either way.
    readonly property string scheme: "tonal-spot"

    // matugen's `-m/--mode` -- light, dark or smart (matugen picks from the
    // source colour itself; confirmed against `matugen --help` on this
    // machine, same as scheme above). Not in Settings.qml's interface yet, so
    // this is the only place it lives. scripts/wallpaper-apply.sh reads it
    // from here and, same as `scheme`, never leaves the flag off the matugen
    // call -- an image going light without anyone asking it to is exactly
    // the failure mode an implicit mode produces.
    readonly property string colorMode: "dark"

    // ── session-aware wallpaper ──────────────────────────────
    // Off until switched on: a shell that changes the user's own wallpaper
    // without being asked is a bug, so nothing below ever runs unless this
    // is true. Services/Wallpapers.qml is the only reader.
    readonly property bool autoWallpaper: false

    // The workspace indicator picks up a faint accent edge on the beat while
    // something is playing, and is completely inert when nothing is. Off by
    // default: it is a decoration on the one element whose real job is to say
    // which workspace you are on, and that job comes first.
    readonly property bool workspaceBeatGlow: false

    // Four named local-time bands rather than a sunrise calculation -- solar
    // position is a dependency this shell does not need just to look
    // different at 3pm than at 11pm. `startHour` is the local hour (0-23) a
    // band takes over at; the active one is whichever band has the highest
    // startHour at or below the current hour, and the band with the latest
    // startHour of all covers the wrap through midnight down to the earliest
    // one. `path` is a placeholder: these four files already exist under
    // ~/Pictures/wall and were picked in listing order, not for what they
    // show, so repoint each one at whichever image actually belongs in that
    // part of the day.
    readonly property var wallpaperBands: [
        { name: "morning",   startHour: 6,  path: `${Quickshell.env("HOME")}/Pictures/wall/bsd.png` },
        { name: "afternoon", startHour: 12, path: `${Quickshell.env("HOME")}/Pictures/wall/planet.png` },
        { name: "evening",   startHour: 18, path: `${Quickshell.env("HOME")}/Pictures/wall/lain1.png` },
        { name: "night",     startHour: 22, path: `${Quickshell.env("HOME")}/Pictures/wall/skel.png` }
    ]

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
    // Corner radii, smallest first. `radiusPill` is deliberately larger than
    // any element that uses it -- Qt clamps a radius to half the shorter side,
    // so one value means "fully rounded" at every height and spares the
    // `height / 2` binding that was written sixteen times.
    readonly property int radiusChip: 4
    readonly property int radiusCard: 8
    readonly property int radiusPopover: 12
    readonly property int radiusIsland: 16
    readonly property int radiusPill: 999
    readonly property int borderWidth: 1

    // The smooth-min blend radius `Blob.qml` folds every island and open
    // card through, in place of the hand-fitted `BarJunction` fillets it
    // replaces (see that file, retired alongside this constant's
    // introduction, for the corner-by-corner geometry it used to take three
    // `BarJunction` instances per side to describe). A circular smooth-min
    // at radius `k` rounds a square meeting of two boxes into an arc of
    // very nearly that same radius -- so `k` is pinned to `radiusIsland`
    // itself rather than picked independently: the fillets it replaces
    // floored at 0 and grew to a maximum of exactly `radiusIsland` (see the
    // `filletLeft`/`filletRight` `radius` bindings BarPopup.qml used to
    // carry), and matching the ceiling of that range is what keeps a card
    // planted flush against its island -- the everyday, fully-merged case --
    // reading at the same corner size it always has. Tuned by comparing the
    // rendered result side by side against the old fillet's corner, not
    // picked from theory: that visual comparison is what confirms this
    // value, not the formula above it, which only explains why 16 rather
    // than 24 or 32 was the first number tried.
    readonly property real blobSmoothK: 16

    // ── interaction ──────────────────────────────────────────
    // How far a surface lifts under the pointer. These are opacities of the
    // foreground colour laid over whatever the element already is, so one pair
    // of numbers reads the same on a bar island, a popup row and a menu entry.
    // Press is deliberately not much darker than hover: the press state has to
    // register inside the ~90ms a click lasts, and a large jump reads as a
    // flash rather than as a button going down.
    readonly property real opacityHover: 0.08
    readonly property real opacityPress: 0.16
    // Translucency of every surface the bar is made of -- islands and popup
    // bodies alike. One number and not two: a card now opens flush against the
    // island above it, and it only reads as the same piece of glass carrying on
    // downwards if there is no step in tone at the line where they meet. The
    // islands used to sit at 0.28 against popup bodies at 0.6; the popups'
    // number is the one that stayed, because a card full of text is what has to
    // stay legible over whatever the wallpaper is doing, where a thin strip of
    // icons does not.
    readonly property real opacitySurface: 0.6

    // ── spacing ──────────────────────────────────────────────
    // One ladder, used for both gaps between things and padding inside them.
    // `space` is the default; reach for a neighbour only when the default
    // visibly crowds or strands.
    readonly property real spaceTight: 4 * uiScale
    readonly property real spaceSnug: 6 * uiScale
    readonly property real space: 8 * uiScale
    readonly property real spaceLoose: 10 * uiScale
    readonly property real spaceWide: 12 * uiScale
    readonly property real spaceEdge: 14 * uiScale

    // ── type ─────────────────────────────────────────────────
    // Single families, not lists: Qt 6.11's QML `font` value type registers no
    // `families` property (the Quick plugin exposes letterSpacing, styleName
    // and variableAxes, but nothing for a family list), so a fallback chain
    // cannot be written here. Where caelusevka has no glyph, Qt falls through
    // to whatever fontconfig nominates; naming CaskaydiaCove as that fallback
    // is a fontconfig rule, not a shell setting.
    readonly property string fontFamily: "caelusevka"
    readonly property string symbolFamily: "Material Symbols Rounded"

    // ── ui scale (idea 9: Accessibility settings pane) ─────────
    // One multiplier over the type and spacing ladders just below, so raising
    // it enlarges text and the room around it together instead of one moving
    // faster than the other and the rhythm between them drifting. Read the
    // same way `dynamicColour` is, at the top of this file: through
    // Settings.uiScale once that singleton has landed in the tree, falling
    // back to identity everywhere it has not -- and Settings.qml's own
    // JsonAdapter default is the same 1.0 this falls back to, so the two
    // never disagree. Deliberately does NOT reach barHeight, barInset or any
    // other bar-geometry token: those set the compositor's reserved strip and
    // exclusive zone, and a slider that resizes those out from under Hyprland
    // is a bug, not an accessibility feature. Radii are left alone too --
    // shape, not something a person reads at a size. Only the type sizes and
    // spacing ladder below -- what popups actually set font.pixelSize and
    // Layout.spacing/margins from -- scale, and only for the popups that read
    // them; the bar keeps its footprint fixed at any scale.
    readonly property real uiScale: typeof Settings !== "undefined" ? Settings.uiScale : 1.0

    readonly property real sizeLabel: 12 * uiScale
    readonly property real sizeBody: 13 * uiScale
    readonly property real sizeLead: 15 * uiScale
    readonly property real sizeTitle: 18 * uiScale

    // ── bar geometry ─────────────────────────────────────────
    // `barHeight` is the strip the compositor reserves; the islands inside it
    // are `barHeight - 2 * barInset` tall, so the inset is the gap above and
    // below them and is what makes them read as floating rather than docked.
    // `barMargin` is the same gap at the left and right screen edges, and
    // `barIslandPad` is how far an island reaches past the pills it holds.
    readonly property int barHeight: 44
    readonly property int barInset: 6
    readonly property int barMargin: 14
    readonly property int barSpacing: 8
    readonly property int barIslandPad: 6
}
