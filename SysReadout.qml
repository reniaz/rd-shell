import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The three system readings as one pill's worth of content. Each group is an
// icon, the figure that says how hard that part is working, and the figure that
// says what it costs -- degrees for the two that heat up, gigabytes for the one
// that does not.
//
// The icon carries the load colour and the trailing figure its own, so a cool
// machine under full load and a hot idle one do not look alike.
RowLayout {
    id: root

    spacing: 12

    Repeater {
        model: [
            {
                icon: "memory",
                value: SysMon.cpuPercent >= 0 ? SysMon.cpuPercent + "%" : "--",
                load: Colors.usage(SysMon.cpuPercent, Colors.sysIcon),
                trailing: Format.temp(SysMon.cpuTemp),
                trailingColor: Colors.heat(SysMon.cpuTemp, SysMon.cpuWarm, SysMon.cpuHot, Colors.sysIcon),
                shown: SysMon.cpuTemp >= 0
            },
            {
                // VRAM and not utilisation: nvidia-settings does not report how
                // busy the card is, and a made-up percentage is worse than the
                // real one next to it.
                icon: "developer_board",
                value: SysMon.gpuMemPercent >= 0 ? SysMon.gpuMemPercent + "%" : "--",
                load: Colors.usage(SysMon.gpuMemPercent, Colors.sysIcon),
                trailing: Format.temp(SysMon.gpuTemp),
                trailingColor: Colors.heat(SysMon.gpuTemp, SysMon.gpuWarm, SysMon.gpuHot, Colors.sysIcon),
                shown: SysMon.gpuTemp >= 0
            },
            {
                icon: "memory_alt",
                value: SysMon.memPercent >= 0 ? SysMon.memPercent + "%" : "--",
                load: Colors.usage(SysMon.memPercent, Colors.sysIcon),
                trailing: Format.human(SysMon.memUsed),
                // Not the muted grey the popup uses for secondary text: on a
                // black pill at 13px that grey is a smudge rather than a
                // number. Dim next to the reading beside it is enough.
                trailingColor: Colors.sysBody,
                shown: SysMon.memPercent >= 0
            }
        ]

        RowLayout {
            id: reading

            required property var modelData

            spacing: 6
            visible: reading.modelData.shown

            Text {
                text: reading.modelData.icon
                color: reading.modelData.load
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16

                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Text {
                text: reading.modelData.value
                color: Colors.fg
                font.family: "caelusevka"
                font.pixelSize: 16
            }

            // Smaller and coloured on its own terms: it is the second thing
            // read about each part, not a second headline.
            Text {
                text: reading.modelData.trailing
                color: reading.modelData.trailingColor
                font.family: "caelusevka"
                font.pixelSize: 13

                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }
}
