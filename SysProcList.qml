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

    readonly property ListModel processes: root.memory ? SysMon.topMem : SysMon.topCpu

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
                id: procRow

                // The two roles this list adds to the ones the row itself takes.
                // Only one of them is ever shown -- which one is the difference
                // between the two tabs -- but both are declared, because a role
                // left undeclared on a delegate with required properties is not
                // reachable from it at all.
                required property real cpu
                required property real rss

                value: root.memory
                    ? Format.human(procRow.rss)
                    : procRow.cpu.toFixed(1) + "%"
            }
        }

        Text {
            text: "sampling…"
            color: Colors.sysMeta
            font.family: "caelusevka"
            font.pixelSize: 12
            // count, not length: a ListModel is not an array. It also stays
            // filled between openings now, so this line is only ever seen on the
            // first open of a session rather than on every one.
            visible: root.processes.count === 0
            Layout.leftMargin: 9
            Layout.topMargin: 2
            Layout.bottomMargin: 2
        }
    }
}
