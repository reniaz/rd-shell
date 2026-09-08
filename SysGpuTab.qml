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

    readonly property real naturalHeight: content.implicitHeight

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 10

        SysCard {
            title: SysMon.gpuName !== "" ? SysMon.gpuName : "Graphics card"
            visible: SysMon.gpuTemp >= 0

            trailing: [
                Text {
                    text: Format.temp(SysMon.gpuTemp)
                    color: Colors.heat(SysMon.gpuTemp, SysMon.gpuWarm, SysMon.gpuHot, Colors.sysColor)
                    font.family: "caelusevka"
                    font.pixelSize: 13
                }
            ]

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
                label: "Fan"
                // A stopped fan on an idle card is the design working, not a
                // missing reading, so zero is printed as what it is.
                value: SysMon.gpuFan > 0 ? SysMon.gpuFan + " rpm" : "stopped"
                visible: SysMon.gpuFan >= 0
            }

            SysStatRow {
                label: "Driver"
                value: SysMon.gpuDriver
                visible: SysMon.gpuDriver !== ""
            }
        }

        SysCard {
            title: "Radeon integrated"
            visible: SysMon.igpuTemp >= 0

            trailing: [
                Text {
                    text: Format.temp(SysMon.igpuTemp)
                    color: Colors.heat(SysMon.igpuTemp, SysMon.cpuWarm, SysMon.cpuHot, Colors.sysColor)
                    font.family: "caelusevka"
                    font.pixelSize: 13
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
    }
}
