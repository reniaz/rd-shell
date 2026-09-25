import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// What the processor is doing: the aggregate, every thread on its own, and the
// programs responsible.
Item {
    id: root

    // Read by the panel to size itself to the open tab. A StackLayout reports
    // the tallest of its pages, which would hold the card at the height of
    // whichever tab is longest.
    // The list's hidden rows count too: this is the height the page would
    // like, and the popup only settles for less when the screen is full.
    readonly property real naturalHeight: content.implicitHeight + procs.overflow

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Caelus.spaceLoose

        SysCard {
            title: SysMon.cpuModel !== "" ? SysMon.cpuModel : "Processor"

            trailing: [
                Text {
                    text: Format.temp(SysMon.cpuTemp)
                    color: Colors.heat(SysMon.cpuTemp, SysMon.cpuWarm, SysMon.cpuHot, Colors.sysColor)
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }
            ]

            SysMeter {
                label: "Load"
                value: SysMon.cpuPercent >= 0 ? SysMon.cpuPercent + "%" : "--"
                fraction: Math.max(0, SysMon.cpuPercent) / 100
                fill: Colors.usage(SysMon.cpuPercent, Colors.sysColor)
            }

            SysCores {
                cores: SysMon.cores
                Layout.topMargin: 2
                Layout.bottomMargin: 2
            }

            SysStatRow {
                label: "Threads"
                value: SysMon.cores.length + " ·  " + (SysMon.cpuMhz / 1000).toFixed(2) + " GHz"
            }

            SysStatRow {
                label: "Load average"
                value: SysMon.load.map(l => l.toFixed(2)).join("   ")
            }

            SysStatRow {
                label: "Processes"
                value: SysMon.procCount
            }
        }

        // Last two minutes of the reading above, so a spike that has already
        // passed is not lost the moment it drops off the live number.
        // ClaudeAreaChart takes an array of objects keyed by `valueKey`;
        // cpuHistory is a plain array of numbers (see the SysMon API
        // contract), so it is wrapped rather than the chart being taught a
        // second, bar-specific input shape.
        SysCard {
            title: "History"

            ClaudeAreaChart {
                Layout.fillWidth: true
                model: (SysMon.cpuHistory ?? []).map(v => ({ v }))
                valueKey: "v"
                fill: Colors.sysColor
            }
        }

        SysProcList {
            id: procs

            defaultSort: "cpu"
            availableHeight: root.height - procs.y
        }
    }
}
