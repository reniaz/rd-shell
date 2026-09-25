import QtQuick
import QtQuick.Layouts
import qs.Config

// Same idea as SysMeter, but three shares of one whole instead of one share
// of a floating total: used, cached and free memory are stacked on a single
// track because together -- not each read against the total on its own --
// is what actually says whether the machine is under pressure. Cache sitting
// visibly reclaimable next to used is the whole point; a lone "in use" bar
// cannot show that distinction at all.
ColumnLayout {
    id: root

    property real used: 0
    property real cache: 0
    property real free: 0
    property color usedColor: Colors.sysColor
    property color cacheColor: Colors.sysMeta
    property int thickness: 9

    readonly property real total: root.used + root.cache + root.free

    // Eased the same way SysMeter eases its own single fraction: on the
    // reading, not on the pixel width drawn from it below, so a segment that
    // has not moved since the last poll is never seen to snap into place on
    // a layout pass it had nothing to do with. Not `readonly` despite never
    // being assigned by hand -- a Behavior has to be able to write the
    // property as it eases, which a `readonly` binding refuses (see SysCores
    // and BarPopup's own `reveal` for the same non-`readonly` pattern).
    property real usedFraction: root.total > 0 ? root.used / root.total : 0
    property real cacheFraction: root.total > 0 ? root.cache / root.total : 0

    Behavior on usedFraction {
        NumberAnimation { duration: Motion.slow; easing.type: Motion.standard }
    }
    Behavior on cacheFraction {
        NumberAnimation { duration: Motion.slow; easing.type: Motion.standard }
    }

    Layout.fillWidth: true
    spacing: 5

    Rectangle {
        id: track

        Layout.fillWidth: true
        implicitHeight: root.thickness
        radius: Caelus.radiusPill
        color: Colors.sysTrack

        Rectangle {
            x: 0
            width: Math.round(track.width * root.usedFraction)
            height: parent.height
            radius: parent.radius
            color: root.usedColor
        }

        Rectangle {
            x: Math.round(track.width * root.usedFraction)
            width: Math.round(track.width * root.cacheFraction)
            height: parent.height
            radius: 0
            color: root.cacheColor
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Caelus.spaceWide

        Repeater {
            model: [
                { label: "Used", value: root.used, color: root.usedColor },
                { label: "Cache", value: root.cache, color: root.cacheColor },
                { label: "Free", value: root.free, color: Colors.sysMeta }
            ]

            RowLayout {
                id: chip

                required property var modelData

                spacing: 4

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: chip.modelData.color
                }

                Text {
                    text: chip.modelData.label + " " + Format.human(chip.modelData.value)
                    color: Colors.sysMeta
                    font.family: Caelus.fontFamily
                    font.pixelSize: 11
                }
            }
        }
    }
}
