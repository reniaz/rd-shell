import QtQuick
import qs.Config
import qs.Services

// A radial mini-EQ meant to sit around circular album art: one thin bar per
// Cava band, spaced evenly around the circle and rotated to point outward
// from its centre. Built from rotated Rectangles rather than QtQuick.Shapes
// or a Canvas -- a bar's length is a plain Rectangle height, so a Behavior
// animates it for free, which is exactly the capability ClaudeDonutChart.qml
// (line 26) and ClaudeAreaChart.qml (line 58) both note Canvas does not have.
Item {
    id: root

    // Outer diameter of the whole ring, bars at full length included.
    // Whoever places this sizes it larger than the art it wraps and centres
    // the two on top of each other; the gap between them is implied by
    // `barMaxLength` below, not a separate property.
    required property int diameter
    property color tint: Colors.popupAccent

    readonly property int count: Cava.bars ?? 12
    readonly property real barThickness: 2
    readonly property real barMinLength: 3
    readonly property real barMaxLength: 9

    // Cava.available is false with the binary not installed, and Cava.active
    // stays false for every player that is paused -- both leave this at rest.
    // Nothing here reacts to `available` directly: `active` already implies
    // it (see the contract), so one flag is enough.
    readonly property bool live: Cava.active

    // Geometry never follows `live`: `implicitWidth`/`Height` stay pinned to
    // `diameter` whether or not the ring is drawn, so whatever centres album
    // art on top of this never reflows the moment playback starts or stops.
    // Only `visible` follows it, and the Repeater's model with it -- an
    // inactive ring holds zero delegates rather than `count` idle ones, so it
    // costs nothing beyond the one boolean read.
    visible: root.live
    implicitWidth: root.diameter
    implicitHeight: root.diameter

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

                readonly property real level: {
                    const l = Cava.levels;
                    return (l && spoke.index < l.length) ? l[spoke.index] : 0;
                }
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
