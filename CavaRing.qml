import QtQuick
import qs.Config
import qs.Services
import "./CavaNormalize.js" as CavaNorm

// A radial mini-EQ meant to sit around circular album art: dense, thin bars
// spaced evenly around the circle and rotated to point outward from its
// centre, sampling Cava's twelve real bands by interpolating between
// neighbours rather than drawing one bar per band -- see `_levelAt` below.
// Built from rotated Rectangles rather than QtQuick.Shapes or a Canvas -- a
// bar's length is a plain Rectangle height, so a Behavior animates it for
// free, which is exactly the capability ClaudeDonutChart.qml (line 26) and
// ClaudeAreaChart.qml (line 58) both note Canvas does not have.
Item {
    id: root

    // Outer diameter of the whole ring, bars at full length included.
    // Whoever places this sizes it larger than the art it wraps and centres
    // the two on top of each other; the gap between them is implied by
    // `barMaxLength` below, not a separate property.
    required property int diameter
    property color tint: Colors.popupAccent

    // Which spectrum to draw: the islands' everything-but-wayvibes mix by
    // default; DesktopMedia hands in `Cava.desktop` instead.
    property CavaFeed feed: Cava.islands

    // ── tuning ────────────────────────────────────────────────
    // Every number that shapes the ring's reach, gathered here so a future
    // retune is a one-line change instead of a hunt through the geometry
    // and the Repeater below. Reworked off live feedback -- "too few bars
    // in one corner", then "hits way too hard" -- so these are picked to
    // sit at a calm middle, not at whatever first looked right.

    // A third less reach than the ring first shipped with (0.2): the ring
    // was landing near-full-length on ordinary passages, not just hits.
    readonly property real _barMaxRatio: 0.133
    readonly property real _barMinRatio: 0.07

    // How hard the bars hit is CavaNormalize.options' shared tuning, the
    // same as every other visualizer's -- only the geometry lives here.

    // One bar roughly every 4.5px of arc rather than one per Cava band --
    // twelve wedges around a ring the size of DesktopMedia's art read as a
    // clock face, not a spectrum. Deriving the count from the ring's own
    // circumference is what keeps a small ring (MediaPopup's compact art)
    // proportionally sparser than a big one (DesktopMedia's) without either
    // needing its own hand-picked number -- see `_levelAt` for how those
    // extra bars still only ever read twelve real values.
    readonly property real _arcPerBar: 4.5
    readonly property int count: Math.max(1, Math.round(Math.PI * root.diameter / root._arcPerBar))

    readonly property real barThickness: 1.5

    // Scaled off `diameter` rather than fixed: a ring this size on
    // MediaPopup's compact art and one twice the size on DesktopMedia's
    // idle card should both read as "bars reaching about the same fraction
    // of the ring's own radius", not the smaller one looking spiky and the
    // larger one looking clipped.
    readonly property real barMaxLength: Math.max(5, Math.round(root.diameter * root._barMaxRatio))
    readonly property real barMinLength: Math.max(2, Math.round(root.diameter * root._barMinRatio))

    // `active` stays false with the binary not installed and while nothing
    // the feed hears is sounding -- both leave this at rest.
    readonly property bool live: root.feed.active

    // Geometry never follows `live`: `implicitWidth`/`Height` stay pinned to
    // `diameter` whether or not the ring is drawn, so whatever centres album
    // art on top of this never reflows the moment playback starts or stops.
    // Only `visible` follows it, and the Repeater's model with it -- an
    // inactive ring holds zero delegates rather than `count` idle ones, so it
    // costs nothing beyond the one boolean read.
    visible: root.live
    implicitWidth: root.diameter
    implicitHeight: root.diameter

    // ── per-band equalisation ────────────────────────────────
    // `_ref`/`_display` are this ring's own copy of CavaNormalize's state
    // -- "ring-local" means MediaPopup's small ring and this one never
    // share a reference, so one player's ring never drives another's.
    // `_ref` is written in place by CavaNorm.step (nothing reads it but
    // that call, so it needs no change notification); `_display` is
    // replaced wholesale each frame, which is what makes the interpolation
    // below re-evaluate.
    property var _ref: CavaNorm.zeros(Cava.bars, 0)
    property var _display: CavaNorm.zeros(Cava.bars, 0)

    readonly property var _normOpts: CavaNorm.options(root.feed.framerate)

    Connections {
        target: root.feed
        function onLevelsChanged() {
            if (!root.live) return;
            root._display = CavaNorm.step(root.feed.levels, root._ref, root._display, root._normOpts);
        }
    }

    // Matches CavaFeed's own reset on `active` going false: a stale frame
    // sitting in `_display` would otherwise be what the ring drew for one
    // frame the next time playback starts, before a fresh one arrives.
    onLiveChanged: if (!root.live) {
        root._ref = CavaNorm.zeros(Cava.bars, 0);
        root._display = CavaNorm.zeros(Cava.bars, 0);
    }

    // Maps one spoke's angle (0 at the top, clockwise) onto the twelve real
    // bands, interpolated and mirrored left/right: folding everything past
    // 180deg back onto 0-180 means the bar at, say, 40deg and the one at
    // 320deg always read the same band, so the low end sits at the very
    // top and bottom of the ring and the spectrum climbs symmetrically up
    // both sides to meet at the bottom -- one sweep, not sixty-odd bars
    // each pinned to whichever one of twelve real values their raw index
    // happened to divide into, which is what used to leave every bar past
    // the twelfth reading a flat zero and the whole ring's motion bunched
    // into the first slice of its circumference.
    function _levelAt(angleDeg) {
        const d = root._display;
        const n = d.length;
        if (n === 0) return 0;
        const folded = angleDeg <= 180 ? angleDeg : 360 - angleDeg;
        const pos = (folded / 180) * (n - 1);
        const lo = Math.floor(pos);
        const hi = Math.min(n - 1, lo + 1);
        const frac = pos - lo;
        return d[lo] * (1 - frac) + d[hi] * frac;
    }

    Repeater {
        model: root.live ? root.count : 0

        Item {
            id: spoke

            required property int index

            // Fills `root`, so its own centre -- the default rotation origin
            // for an Item -- lands exactly on root's centre too, whatever
            // `diameter` turns out to be.
            anchors.fill: parent
            rotation: spoke.index * (360 / root.count)

            Rectangle {
                id: bar

                readonly property real level: root._levelAt(spoke.rotation)
                readonly property real barLength: root.barMinLength
                    + bar.level * (root.barMaxLength - root.barMinLength)

                // The inner edge (`y + height`) sits at a fixed radius of
                // `diameter/2 - barMaxLength` from centre no matter the level;
                // only the outer tip moves, reaching exactly `diameter/2` --
                // the ring's own outer edge -- at a full-scale reading.
                x: (root.diameter - root.barThickness) / 2
                y: root.barMaxLength - bar.barLength
                width: root.barThickness
                height: bar.barLength
                radius: root.barThickness / 2
                color: root.tint

                Behavior on height {
                    NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
                }
            }
        }
    }
}
