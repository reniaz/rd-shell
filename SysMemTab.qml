import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// Memory, and what is holding it.
Item {
    id: root

    readonly property real naturalHeight: content.implicitHeight

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 10

        SysCard {
            title: "Memory"

            trailing: [
                Text {
                    text: SysMon.memPercent >= 0 ? SysMon.memPercent + "%" : "--"
                    color: Colors.usage(SysMon.memPercent, Colors.sysColor)
                    font.family: "caelusevka"
                    font.pixelSize: 13
                }
            ]

            SysMeter {
                label: "In use"
                value: Format.human(SysMon.memUsed) + " / " + Format.human(SysMon.memTotal)
                fraction: SysMon.memTotal > 0 ? SysMon.memUsed / SysMon.memTotal : 0
                fill: Colors.usage(SysMon.memPercent, Colors.sysColor)
            }

            SysMeter {
                label: "Swap"
                value: Format.human(SysMon.swapUsed) + " / " + Format.human(SysMon.swapTotal)
                fraction: SysMon.swapTotal > 0 ? SysMon.swapUsed / SysMon.swapTotal : 0
                fill: Colors.usage(SysMon.swapPercent, Colors.sysColor)
                thickness: 5
                visible: SysMon.swapTotal > 0
            }

            SysStatRow {
                label: "Available"
                value: Format.human(SysMon.memAvail)
            }

            SysStatRow {
                // Not counted as used above -- the kernel hands it back on
                // demand -- but it is the difference between this reading and
                // the one every other tool prints, so it is stated rather than
                // quietly dropped.
                label: "Cache and buffers"
                value: Format.human(SysMon.memCached)
            }
        }

        SysProcList { memory: true }
    }
}
