import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// A grid of cells whose colour is their value: hour-of-day across, weekday
// down. A bar chart of twenty-four hours is twenty-four labels nobody reads,
// while a strip of twenty-four cells is a shape -- and the shape is the answer,
// because the question is "when do I work", not "how many turns at 3am".
Item {
    id: root

    // Either a `columns`-long array (one strip) or a `columns * rows`-long one
    // laid out row-major. Nothing else is accepted, and a short array simply
    // leaves its missing cells empty.
    property var model: []
    property string valueKey: "turns"

    property int columns: 24
    property int rows: 1

    // Empty for a bare strip. When set it must hold one entry per row, and the
    // gutter it occupies is sized from the longest of them.
    property var rowLabels: []

    property int cellHeight: 14
    property int gap: 2

    property int hoverIndex: -1

    function _cell(r, c) {
        const a = root.model ?? [];
        const i = r * root.columns + c;
        return (i >= 0 && i < a.length) ? a[i] : null;
    }

    function cellValue(cell) {
        const v = cell ? cell[root.valueKey] : 0;
        return typeof v === "number" && isFinite(v) ? v : 0;
    }

    readonly property real peak: {
        const a = root.model ?? [];
        let m = 0;
        for (let i = 0; i < a.length; i++) m = Math.max(m, root.cellValue(a[i]));
        return m;
    }

    // The ramp starts at a visible floor rather than at the empty colour, so a
    // cell with one turn in it is still distinguishable from a cell with none.
    // Without that floor the bottom third of every ramp reads as background and
    // a quiet hour and a dead hour look identical.
    function colorFor(v) {
        if (v <= 0 || root.peak <= 0) return Colors.claudeHeatEmpty;
        const t = 0.15 + 0.85 * (v / root.peak);
        return Qt.tint(Colors.claudeHeatLow,
                       Qt.rgba(Colors.claudeHeatHigh.r, Colors.claudeHeatHigh.g,
                               Colors.claudeHeatHigh.b, t));
    }

    implicitHeight: root.rows * root.cellHeight + (root.rows - 1) * root.gap + 19

    ColumnLayout {
        anchors.fill: parent
        spacing: root.gap

        Repeater {
            model: root.rows

            RowLayout {
                id: line

                required property int index

                Layout.fillWidth: true
                spacing: root.gap

                Text {
                    text: root.rowLabels[line.index] ?? ""
                    color: Colors.claudeMeta
                    font.family: "caelusevka"
                    font.pixelSize: 13
                    visible: (root.rowLabels ?? []).length > 0
                    // A fixed gutter rather than an implicit one: every row has
                    // to start at the same x or the columns stop being hours.
                    Layout.preferredWidth: visible ? 30 : 0
                }

                Repeater {
                    model: root.columns

                    Rectangle {
                        id: cell

                        required property int index

                        readonly property var record: root._cell(line.index, cell.index)
                        readonly property real value: root.cellValue(cell.record)
                        readonly property int flat: line.index * root.columns + cell.index

                        Layout.fillWidth: true
                        Layout.preferredHeight: root.cellHeight
                        radius: 3
                        color: root.colorFor(cell.value)

                        // The hovered cell keeps its colour and everything else
                        // steps back, which is the same convention the bar
                        // chart uses for the same reason.
                        opacity: root.hoverIndex < 0 || root.hoverIndex === cell.flat ? 1 : 0.45

                        Behavior on color { ColorAnimation { duration: 220 } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: true
                            onEntered: root.hoverIndex = cell.flat
                            onExited: if (root.hoverIndex === cell.flat) root.hoverIndex = -1
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 15
            text: {
                const a = root.model ?? [];
                if (root.hoverIndex < 0 || root.hoverIndex >= a.length) return "";

                const rec = a[root.hoverIndex];
                const v = ClaudeSession.compact(root.cellValue(rec));
                const c = root.hoverIndex % root.columns;
                const r = Math.floor(root.hoverIndex / root.columns);
                const rowName = (root.rowLabels ?? [])[r] ?? "";

                // Columns are hours whenever there are twenty-four of them,
                // which is the only shape this component is ever given; any
                // other width is captioned by index instead of inventing a
                // unit it was never told about.
                const col = root.columns === 24
                    ? (c < 10 ? "0" + c : String(c)) + ":00"
                    : String(c);

                return (rowName !== "" ? rowName + " " : "") + col + " · " + v;
            }
            color: Colors.claudeBody
            font.family: "caelusevka"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
