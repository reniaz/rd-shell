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

    // Which spectrum to draw: the islands' everything-but-wayvibes mix by
    // default; DesktopMedia's idle bars hand in `Cava.desktop` instead.
    property CavaFeed feed: Cava.islands

    // Same per-band equalisation and tuning as CavaRing -- see
    // CavaNormalize.js -- for every instance, the bar strip's included, so
    // the island and the desktop card react to a hit the same way instead
    // of the strip drawing raw levels while the card equalises them.
    readonly property bool _live: root.feed.active

    property var _ref: CavaNorm.zeros(Cava.bars, 0)
    property var _display: CavaNorm.zeros(Cava.bars, 0)

    readonly property var _normOpts: CavaNorm.options(root.feed.framerate)

    Connections {
        target: root.feed
        function onLevelsChanged() {
            if (!root._live) return;
            root._display = CavaNorm.step(root.feed.levels, root._ref, root._display, root._normOpts);
        }
    }

    // Matches CavaRing: a stale frame left in `_display` would otherwise be
    // what the bars rested at after playback stops.
    on_LiveChanged: if (!root._live) {
        root._ref = CavaNorm.zeros(Cava.bars, 0);
        root._display = CavaNorm.zeros(Cava.bars, 0);
    }

    // Bar.qml's own reason to collapse to nothing rather than to a row of
    // flat bars: nothing sounding and cava missing entirely both read as
    // `!active` on the feed, and its row should close the gap for
    // every one of those the same way, not just when nothing is running at
    // all. DesktopMedia's idle visualizer sets this false: it needs a
    // stable, hoverable footprint precisely while paused (bars resting at
    // `barFloor`, still hoverable to bring the card up), not a footprint
    // that vanishes the moment playback pauses.
    property bool collapsible: true

    readonly property int _naturalWidth: Cava.bars * root.barWidth
        + Math.max(0, Cava.bars - 1) * root.barSpacing

    implicitWidth: (root.collapsible && !root._live) ? 0 : root._naturalWidth
    implicitHeight: root.barHeight
    clip: true

    // Qt Quick Layouts reserve a slot's spacing for any child that is
    // visible, whatever its width -- so collapsing to 0 alone would leave
    // Bar.qml's row permanently 16px wider than it looks, for the whole time
    // nothing is playing, which is almost always. Tied to the animated width
    // rather than straight to `_live` so the slot is given up only once
    // the shrink has finished, and taken back before the grow starts.
    // Meaningless for a non-collapsible instance, where implicitWidth never
    // reaches 0 in the first place.
    visible: !root.collapsible || root._live || root.implicitWidth > 0

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

                readonly property real level: root._display[bar.index] ?? 0

                anchors.bottom: parent.bottom
                width: root.barWidth
                height: Math.max(root.barFloor, Math.round(bar.level * root.barHeight))
                // Caelus.radiusPill on a 3px-wide bar clamps to fully rounded
                // regardless -- Qt clamps any radius to half the shorter
                // side -- so this reaches for the shared token rather than
                // hand-computing half the width.
                radius: Caelus.radiusPill
                color: Colors.accent

                // The normaliser's own attack/release already keeps the
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
