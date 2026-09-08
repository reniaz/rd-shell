import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services
import "ClaudeSeries.js" as Series

// Captions a ClaudeDonutChart. It takes the donut's own inputs rather than a
// pre-built list of labels, and collapses the tail through the same shared
// function, because a legend that disagrees with its chart about where the
// "other" wedge begins is worse than no legend at all.
ColumnLayout {
    id: root

    property var model: []
    property string labelKey: ""
    property string valueKey: ""
    property bool moneyFormat: false

    // Must match the donut's. See ClaudeSeries.js.
    property int slices: 6

    readonly property var rows: Series.collapse(root.model ?? [], root.valueKey,
                                                root.labelKey, root.slices)
    readonly property real total: Series.total(root.rows)

    Layout.fillWidth: true
    spacing: 4

    Repeater {
        model: root.rows

        RowLayout {
            id: entry

            required property var modelData

            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 8
                implicitHeight: 8
                radius: 2
                color: Colors.claudeSeries[entry.modelData.colorIndex % Colors.claudeSeries.length]
            }

            Text {
                text: entry.modelData.label
                color: Colors.claudeBody
                font.family: "caelusevka"
                font.pixelSize: 13
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // The share is printed beside the figure rather than instead of it:
            // "96%" answers which model dominates, and "$1,496" answers what
            // that cost, and the two questions are asked in the same glance.
            Text {
                text: root.total > 0
                    ? Math.round(entry.modelData.value / root.total * 100) + "%"
                    : ""
                color: Colors.claudeMeta
                font.family: "caelusevka"
                font.pixelSize: 13
            }

            Text {
                text: root.moneyFormat
                    ? ClaudeSession.money(entry.modelData.value)
                    : ClaudeSession.compact(entry.modelData.value)
                color: Colors.claudeTitle
                font.family: "caelusevka"
                font.pixelSize: 13
                visible: root.valueKey !== ""
            }
        }
    }
}
