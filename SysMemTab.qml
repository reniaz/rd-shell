import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// Memory, and what is holding it.
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
            title: "Memory"

            trailing: [
                Text {
                    text: SysMon.memPercent >= 0 ? SysMon.memPercent + "%" : "--"
                    color: Colors.usage(SysMon.memPercent, Colors.sysColor)
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }
            ]

            // Stacked rather than one bar against the total: used, cached and
            // free are three different promises about the same gigabyte, and
            // showing them as one share each is what lets a reader tell "the
            // kernel is holding page cache it can drop" apart from "something
            // is actually leaking". `memFree` is new (see the SysMon API
            // contract); guarded so this still draws sanely as a plain
            // used/free split for the short time before DATA's sampler
            // change lands and starts publishing it.
            SysStackMeter {
                used: SysMon.memUsed
                cache: Math.max(0, SysMon.memAvail - (SysMon.memFree ?? SysMon.memAvail))
                free: SysMon.memFree ?? SysMon.memAvail
                usedColor: Colors.usage(SysMon.memPercent, Colors.sysColor)
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

            SysStatRow {
                label: "zram"
                // Compressed swap: what it is holding, what that costs once
                // packed, and the ratio between the two -- the number that
                // actually says whether zram is earning its keep on this
                // machine right now.
                value: Format.human(SysMon.zramOrig ?? 0) + " → " + Format.human(SysMon.zramCompr ?? 0)
                    + ", " + (SysMon.zramRatio ?? 0).toFixed(1) + "×"
                visible: (SysMon.zramOrig ?? 0) > 0
            }
        }

        // Same two minutes of history the other tabs show, plotting the
        // percentage in the trailing figure above -- see SysCpuTab.qml for
        // why the plain-number array is wrapped before ClaudeAreaChart sees it.
        SysCard {
            title: "History"

            ClaudeAreaChart {
                Layout.fillWidth: true
                model: (SysMon.memHistory ?? []).map(v => ({ v }))
                valueKey: "v"
                fill: Colors.sysColor
            }
        }

        SysProcList {
            id: procs

            defaultSort: "mem"
            availableHeight: root.height - procs.y
        }
    }
}
