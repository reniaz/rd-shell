import QtQuick
import qs.Config
import qs.Services

// A tiny frequency-bar readout for the bar strip, fed straight from
// Services/Cava.qml. Self-contained on purpose: Bar.qml drops in a bare
// `CavaBars {}` next to the media pill and never has to hand it a colour, a
// size, or which player to read -- Cava is what decides whether there is
// anything to show at all.
Item {
    id: root

    readonly property int _barWidth: 3
    readonly property int _spacing: 2
    readonly property int _barHeight: 20
    readonly property int _floor: 2

    readonly property int _naturalWidth: Cava.bars * root._barWidth
        + Math.max(0, Cava.bars - 1) * root._spacing

    // Collapses to nothing rather than to a row of flat bars: no player, a
    // paused one, and cava missing entirely all read as `!active` on the
    // service, and Bar.qml's row should close the gap for every one of those
    // the same way, not just for the case where nothing is running at all.
    implicitWidth: Cava.active ? root._naturalWidth : 0
    implicitHeight: root._barHeight
    clip: true

    // Qt Quick Layouts reserve a slot's spacing for any child that is
    // visible, whatever its width -- so collapsing to 0 alone would leave
    // Bar.qml's row permanently 16px wider than it looks, for the whole time
    // nothing is playing, which is almost always. Tied to the animated width
    // rather than straight to Cava.active so the slot is given up only once
    // the shrink has finished, and taken back before the grow starts.
    visible: Cava.active || root.implicitWidth > 0

    // base, not fast: Motion.qml assigns "a shape changing size in place" to
    // base and names the workspace dot stretching into a capsule as the
    // example, which is the same move this makes when playback starts.
    Behavior on implicitWidth {
        NumberAnimation { duration: Motion.base; easing.type: Motion.standard }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        height: root._barHeight
        spacing: root._spacing

        Repeater {
            model: Cava.bars

            Rectangle {
                id: bar

                required property int index

                readonly property real level: Cava.levels[bar.index] ?? 0

                anchors.bottom: parent.bottom
                width: root._barWidth
                height: Math.max(root._floor, Math.round(bar.level * root._barHeight))
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
