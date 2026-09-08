import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The processes making the reading above them, and the controls that end one.
// Which list -- and so what the right-hand column means -- follows the tab it
// is on: the CPU page has no reason to rank by memory.
SysCard {
    id: root

    property bool memory: false

    readonly property var processes: root.memory ? SysMon.topMem : SysMon.topCpu

    title: root.memory ? "Top by memory" : "Top by processor"

    // Negative margins so the hover highlight runs the full width of the card
    // rather than stopping inside its text column.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: -5
        Layout.rightMargin: -5
        spacing: 1

        Repeater {
            model: root.processes

            SysProcRow {
                required property var modelData

                proc: modelData
                value: root.memory
                    ? Format.human(modelData.rss)
                    : modelData.cpu.toFixed(1) + "%"
            }
        }

        Text {
            text: "sampling…"
            color: Colors.sysMeta
            font.family: "caelusevka"
            font.pixelSize: 12
            visible: root.processes.length === 0
            Layout.leftMargin: 9
            Layout.topMargin: 2
            Layout.bottomMargin: 2
        }
    }
}
