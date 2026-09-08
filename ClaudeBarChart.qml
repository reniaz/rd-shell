import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// Vertical bars over an arbitrary array of records. The caller names the field
// to plot and the field to label with, which is why the same component draws
// cost per day and turns per weekday without either of them having to teach it
// about dates or about weekdays.
Item {
    id: root

    property var model: []
    property string valueKey: ""
    property string labelKey: ""

    // Dates are the reason this exists: "2026-08-28" under a fifteen-pixel bar
    // is illegible, and its last two characters are the only part that varies
    // across the window being drawn.
    property int labelChars: 0

    property color fill: Colors.claudeAccent
    property real barSpacing: 6
    property bool showPeak: true

    // Costs want "$122" and counts want "1.2k"; the chart cannot tell which it
    // is holding, so the caller says.
    property bool moneyFormat: false

    // Which bar the pointer is over, -1 for none. The delegates write it and
    // the caption underneath reads it, which keeps the readout one Text instead
    // of a floating label per bar.
    property int hoverIndex: -1

    readonly property int count: (root.model ?? []).length

    function _row(i) {
        const a = root.model ?? [];
        return (i >= 0 && i < a.length) ? a[i] : null;
    }

    // Anything that is not a finite number counts as zero. The payload is
    // parsed JSON from a shell script, so a missing key is a real possibility
    // and one `undefined` reaching a bar height poisons the whole row.
    function numberOf(row) {
        const v = row ? row[root.valueKey] : 0;
        return typeof v === "number" && isFinite(v) ? v : 0;
    }

    function labelOf(row) {
        if (!row || root.labelKey === "") return "";
        const s = String(row[root.labelKey] ?? "");
        return root.labelChars > 0 ? s.slice(-root.labelChars) : s;
    }

    function valueAt(i) {
        return root.numberOf(root._row(i));
    }

    function labelAt(i) {
        return root.labelOf(root._row(i));
    }

    function formatted(v) {
        return root.moneyFormat ? ClaudeSession.money(v) : ClaudeSession.compact(v);
    }

    // Bars scale against the largest value in the window. A peak of zero stays
    // zero and every fraction below is guarded against it: a week that cost
    // nothing must draw seven floor-height marks, not seven NaNs.
    readonly property real peak: {
        let m = 0;
        for (let i = 0; i < root.count; i++) m = Math.max(m, root.valueAt(i));
        return m;
    }

    readonly property int peakIndex: {
        let at = -1;
        let m = 0;
        for (let i = 0; i < root.count; i++) {
            const v = root.valueAt(i);
            if (v > m) {
                m = v;
                at = i;
            }
        }
        return at;
    }

    implicitHeight: 88

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.barSpacing

            Repeater {
                model: root.model ?? []

                // A RowLayout of Items rather than a Row of Rectangles: each
                // cell takes its width from the layout, and the bar inside
                // reads that cell instead of the row, which would be a loop.
                Item {
                    id: cell

                    required property var modelData
                    required property int index

                    readonly property real fraction: root.peak > 0
                        ? root.numberOf(cell.modelData) / root.peak
                        : 0

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        id: bar

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom

                        // Two pixels of floor so an idle day is still a mark,
                        // and fourteen off the top so the tallest bar never
                        // collides with the figure printed above it.
                        height: Math.max(2, Math.max(0, cell.height - 14) * cell.fraction)
                        radius: 3
                        color: root.fill

                        // Hovering dims the other bars rather than brightening
                        // this one, so a bar keeps the colour its legend
                        // promised for as long as it is on screen.
                        opacity: root.hoverIndex < 0 || root.hoverIndex === cell.index ? 1 : 0.4

                        Behavior on height {
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: bar.top
                        anchors.bottomMargin: 2
                        text: root.formatted(root.numberOf(cell.modelData))
                        color: Colors.claudeMeta
                        font.family: "caelusevka"
                        font.pixelSize: 13

                        // Only the tallest bar, and only while nothing is
                        // hovered: the caption says the same thing the moment
                        // the pointer lands anywhere at all.
                        visible: root.showPeak && root.peak > 0
                            && cell.index === root.peakIndex && root.hoverIndex < 0
                    }

                    // NoButton, because the chart lives inside the panel's
                    // Flickable and a drag that starts on a bar must still
                    // scroll the tab rather than being swallowed here.
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                        onEntered: root.hoverIndex = cell.index
                        // Guarded: entering the neighbour fires before this
                        // exit does, and an unguarded reset would clear the
                        // index the neighbour just claimed.
                        onExited: if (root.hoverIndex === cell.index) root.hoverIndex = -1
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.barSpacing
            visible: root.labelKey !== ""

            Repeater {
                model: root.labelKey !== "" ? (root.model ?? []) : []

                Text {
                    id: tick

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 15
                    text: root.labelOf(tick.modelData)
                    color: root.hoverIndex === tick.index ? Colors.claudeBody : Colors.claudeMeta
                    font.family: "caelusevka"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight

                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }
        }

        // The caption keeps its row even when it is empty. Showing it only
        // while hovering would resize the chart under the pointer, which moves
        // the very bar being read.
        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 15
            text: {
                if (root.hoverIndex < 0 || root.hoverIndex >= root.count) return "";
                const l = root.labelAt(root.hoverIndex);
                const v = root.formatted(root.valueAt(root.hoverIndex));
                return l !== "" ? l + " · " + v : v;
            }
            color: Colors.claudeBody
            font.family: "caelusevka"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
