import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// Both graphics devices. The discrete card reports a temperature, its VRAM and
// its fans; how busy it is lives in NVML, which means nvidia-smi, which this
// driver package does not install. The integrated Radeon reports exactly the
// figure the card withholds, so neither is shown alone.
Item {
    id: root

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
            title: SysMon.gpuName !== "" ? SysMon.gpuName : "Graphics card"
            visible: SysMon.gpuTemp >= 0

            trailing: [
                Text {
                    text: Format.temp(SysMon.gpuTemp)
                    color: Colors.heat(SysMon.gpuTemp, SysMon.gpuWarm, SysMon.gpuHot, Colors.sysColor)
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }
            ]

            // Utilisation, not VRAM, leads now: NVML (see the SysMon API
            // contract) reports how busy the card actually is, which
            // nvidia-settings never could -- the reading the old "shown
            // alone" comment above used to apologise for not having.
            SysMeter {
                label: "Utilisation"
                value: (SysMon.gpuUtil ?? -1) >= 0 ? SysMon.gpuUtil + "%" : "--"
                fraction: Math.max(0, SysMon.gpuUtil ?? 0) / 100
                fill: Colors.usage(SysMon.gpuUtil ?? 0, Colors.sysColor)
                visible: (SysMon.gpuUtil ?? -1) >= 0
            }

            SysMeter {
                label: "VRAM"
                value: Format.human(SysMon.gpuMemUsed) + " / " + Format.human(SysMon.gpuMemTotal)
                fraction: SysMon.gpuMemTotal > 0 ? SysMon.gpuMemUsed / SysMon.gpuMemTotal : 0
                fill: Colors.usage(SysMon.gpuMemPercent, Colors.sysColor)
            }

            // The temperature as a bar as well as a figure: degrees mean
            // nothing without the number they are allowed to reach, and the
            // track ends at the point the card starts throttling itself.
            SysMeter {
                label: "Temperature"
                value: Format.temp(SysMon.gpuTemp) + " of " + SysMon.gpuHot + "°"
                fraction: SysMon.gpuTemp / SysMon.gpuHot
                fill: Colors.heat(SysMon.gpuTemp, SysMon.gpuWarm, SysMon.gpuHot, Colors.sysColor)
                thickness: 5
            }

            SysStatRow {
                label: "Clocks"
                value: (SysMon.gpuClock ?? -1) + " / " + (SysMon.gpuMemClock ?? -1) + " MHz"
                visible: (SysMon.gpuClock ?? -1) >= 0
            }

            SysStatRow {
                label: "Power"
                value: (SysMon.gpuPower ?? -1).toFixed(0) + " / " + (SysMon.gpuPowerLimit ?? -1).toFixed(0) + " W"
                visible: (SysMon.gpuPower ?? -1) >= 0
            }

            SysStatRow {
                label: "Fan"
                // A stopped fan on an idle card is the design working, not a
                // missing reading, so zero is printed as what it is. RPM
                // leads because it is the physical fact; the percent NVML
                // also reports is folded in beside it rather than given its
                // own row.
                value: (SysMon.gpuFan ?? -1) > 0
                    ? SysMon.gpuFan + " rpm (" + (SysMon.gpuFanPercent ?? 0) + "%)"
                    : "stopped"
                visible: (SysMon.gpuFan ?? -1) >= 0
            }

            SysStatRow {
                label: "Power state"
                value: "P" + (SysMon.gpuPstate ?? -1)
                visible: (SysMon.gpuPstate ?? -1) >= 0
            }

            SysStatRow {
                label: "Encode / decode"
                value: (SysMon.gpuEnc ?? 0) + "% / " + (SysMon.gpuDec ?? 0) + "%"
                visible: (SysMon.gpuEnc ?? -1) >= 0 || (SysMon.gpuDec ?? -1) >= 0
            }

            SysStatRow {
                label: "Driver"
                value: SysMon.gpuDriver
                visible: SysMon.gpuDriver !== ""
            }
        }

        // Same two minutes of history the CPU tab shows, plotting utilisation
        // rather than load -- see SysCpuTab.qml for why the plain-number
        // array is wrapped before it reaches ClaudeAreaChart.
        SysCard {
            title: "History"
            visible: SysMon.gpuTemp >= 0

            ClaudeAreaChart {
                Layout.fillWidth: true
                model: (SysMon.gpuHistory ?? []).map(v => ({ v }))
                valueKey: "v"
                fill: Colors.sysColor
            }
        }

        SysCard {
            title: "Radeon integrated"
            visible: SysMon.igpuTemp >= 0

            trailing: [
                Text {
                    text: Format.temp(SysMon.igpuTemp)
                    color: Colors.heat(SysMon.igpuTemp, SysMon.cpuWarm, SysMon.cpuHot, Colors.sysColor)
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }
            ]

            SysMeter {
                label: "Utilisation"
                value: SysMon.igpuBusy >= 0 ? SysMon.igpuBusy + "%" : "--"
                fraction: Math.max(0, SysMon.igpuBusy) / 100
                fill: Colors.usage(SysMon.igpuBusy, Colors.sysColor)
            }

            SysStatRow {
                label: "Package power"
                // Shared silicon: this is the whole CPU package, which is why
                // it moves when nothing is drawing.
                value: SysMon.igpuPower.toFixed(1) + " W"
                visible: SysMon.igpuPower >= 0
            }
        }

        // By VRAM, not by CPU or RSS: this is the one tab where a process's
        // share of the card, not of the machine, is the reading worth
        // ranking on. `gpu: true` also filters out every group the sampler
        // only emitted for the other two tabs' sake (see the union rule in
        // scripts/sysmon.py).
        SysProcList {
            id: procs

            defaultSort: "vram"
            gpu: true
            availableHeight: root.height - procs.y
        }
    }
}
