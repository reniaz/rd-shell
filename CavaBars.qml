import QtQuick
import qs.Config
import qs.Services
import "./CavaNormalize.js" as CavaNorm

// A tiny frequency-bar readout, fed straight from Services/Cava.qml.
// Self-contained on purpose: a bare `CavaBars {}` (Bar.qml's own usage, next
// to the media pill) never has to hand it a colour, a size, or which player
// to read -- Cava is what decides whether there is anything to show at all.
//
// Every dimension below is a public property with the bar strip's own
// values as its default, rather than a private constant: DesktopMedia.qml's
// idle visualizer is the same readout at a bigger, non-collapsing size, and
// overriding a property at the call site is what lets it do that without a
// second copy of this file. A caller that sets nothing gets exactly the bar
// strip's own look, unchanged.
Item {
    id: root

    property int barWidth: 3
    property int barSpacing: 2
    property int barHeight: 20
    property int barFloor: 2

    // Off by default so the bar strip's `CavaBars {}` reads exactly the raw
    // twelve levels it always has -- see Services/Cava.qml's own comment on
    // why noise_reduction plus the height Behavior below is already enough
    // smoothing for that footprint. DesktopMedia's idle visualizer is the
    // one caller that turns this on: sat at a much bigger size with nothing
    // else on the card competing for attention, a quiet player reading as
    // twelve nearly-flat bars would look broken rather than idle, so it
    // opts into the same ring-local equalisation CavaRing uses -- see
    // CavaNormalize.js -- instead of a second copy of that maths.
    property bool normalise: false

    // Same tuning CavaRing settled on after "hits way too hard" and "pins
    // to full at low volume" -- see CavaRing.qml's own header for what each
    // one does and why. Kept in step with the ring rather than re-derived,
    // since the two are meant to look like the same instrument at two
    // sizes, not two different ones.
    readonly property real _eqGainMin: 1
    readonly property real _eqGainMax: 3
    readonly property real _eqRefFloor: 0.02
    readonly property int _eqRefMs: 2500
    readonly property real _headroom: 0.75
    readonly property real _lift: 0.75
    readonly property int _attackMs: 190
    readonly property int _releaseMs: 260

    property var _ref: CavaNorm.zeros(Cava.bars, 0)
    property var _display: CavaNorm.zeros(Cava.bars, 0)

    function _rate(ms) {
        return 1 - Math.pow(0.05, 1 / (Cava.framerate * ms / 1000));
    }

    readonly property var _normOpts: ({
        refRate: root._rate(root._eqRefMs),
        gainMin: root._eqGainMin,
        gainMax: root._eqGainMax,
        refFloor: root._eqRefFloor,
        headroom: root._headroom,
        lift: root._lift,
        attack: root._rate(root._attackMs),
        release: root._rate(root._releaseMs)
    })

    Connections {
        target: Cava
        function onLevelsChanged() {
            if (!root.normalise) return;
            root._display = CavaNorm.step(Cava.levels, root._ref, root._display, root._normOpts);
        }
    }

    // Bar.qml's own reason to collapse to nothing rather than to a row of
    // flat bars: no player, a paused one, and cava missing entirely all read
    // as `!active` on the service, and its row should close the gap for
    // every one of those the same way, not just when nothing is running at
    // all. DesktopMedia's idle visualizer sets this false: it needs a
    // stable, hoverable footprint precisely while paused (bars resting at
    // `barFloor`, still hoverable to bring the card up), not a footprint
    // that vanishes the moment playback pauses.
    property bool collapsible: true

    readonly property int _naturalWidth: Cava.bars * root.barWidth
        + Math.max(0, Cava.bars - 1) * root.barSpacing

    implicitWidth: (root.collapsible && !Cava.active) ? 0 : root._naturalWidth
    implicitHeight: root.barHeight
    clip: true

    // Qt Quick Layouts reserve a slot's spacing for any child that is
    // visible, whatever its width -- so collapsing to 0 alone would leave
    // Bar.qml's row permanently 16px wider than it looks, for the whole time
    // nothing is playing, which is almost always. Tied to the animated width
    // rather than straight to Cava.active so the slot is given up only once
    // the shrink has finished, and taken back before the grow starts.
    // Meaningless for a non-collapsible instance, where implicitWidth never
    // reaches 0 in the first place.
    visible: !root.collapsible || Cava.active || root.implicitWidth > 0

    // base, not fast: Motion.qml assigns "a shape changing size in place" to
    // base and names the workspace dot stretching into a capsule as the
    // example, which is the same move this makes when playback starts.
    Behavior on implicitWidth {
        NumberAnimation { duration: Motion.base; easing.type: Motion.standard }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        height: root.barHeight
        spacing: root.barSpacing

        Repeater {
            model: Cava.bars

            Rectangle {
                id: bar

                required property int index

                readonly property real level: root.normalise
                    ? (root._display[bar.index] ?? 0)
                    : (Cava.levels[bar.index] ?? 0)

                anchors.bottom: parent.bottom
                width: root.barWidth
                height: Math.max(root.barFloor, Math.round(bar.level * root.barHeight))
                // Caelus.radiusPill on a 3px-wide bar clamps to fully rounded
                // regardless -- Qt clamps any radius to half the shorter
                // side -- so this reaches for the shared token rather than
                // hand-computing half the width.
                radius: Caelus.radiusPill
                color: Colors.accent

                // cava's own noise_reduction (default 77, left untouched in
                // the config Cava.qml writes) already keeps the incoming
                // levels from jumping around; this is what turns the steps
                // between frames arriving roughly thirty times a second into
                // a line instead of a strobe.
                Behavior on height {
                    NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
                }
            }
        }
    }
}
