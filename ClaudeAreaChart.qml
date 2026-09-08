import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The same inputs as ClaudeBarChart, drawn as a filled curve. Bars answer
// "which day was expensive"; a curve answers "how fast is this growing", which
// is the only question a running total can be asked -- and a running total
// drawn as bars is nine bars that all look the same height.
Item {
    id: root

    property var model: []
    property string valueKey: ""
    property string labelKey: ""
    property color fill: Colors.claudeAccent
    property bool moneyFormat: false

    // Plot the running total instead of each day's own figure.
    property bool cumulative: false

    property int hoverIndex: -1

    readonly property int count: (root.model ?? []).length

    // Resolved once per model change rather than per paint: the Canvas repaints
    // on every hover and on every resize, and re-walking the payload each time
    // would parse the same numbers a hundred times a second.
    readonly property var points: {
        const src = root.model ?? [];
        const out = [];
        let run = 0;
        for (let i = 0; i < src.length; i++) {
            const raw = src[i] ? src[i][root.valueKey] : 0;
            const v = typeof raw === "number" && isFinite(raw) ? raw : 0;
            run += v;
            out.push(root.cumulative ? run : v);
        }
        return out;
    }

    readonly property real peak: {
        let m = 0;
        for (let i = 0; i < root.points.length; i++) m = Math.max(m, root.points[i]);
        return m;
    }

    function labelAt(i) {
        const src = root.model ?? [];
        if (root.labelKey === "" || i < 0 || i >= src.length) return "";
        return String(src[i][root.labelKey] ?? "");
    }

    function formatted(v) {
        return root.moneyFormat ? ClaudeSession.money(v) : ClaudeSession.compact(v);
    }

    // Canvas takes no Behavior, so the curve grows by scaling every plotted
    // height through this instead. See ClaudeDonutChart for the same device.
    property real progress: 0

    implicitHeight: 96

    Component.onCompleted: grow.start()

    NumberAnimation {
        id: grow
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 520
        easing.type: Easing.OutCubic
    }

    onPointsChanged: area.requestPaint()
    onProgressChanged: area.requestPaint()
    onFillChanged: area.requestPaint()

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Item {
            id: plot

            Layout.fillWidth: true
            Layout.fillHeight: true

            Canvas {
                id: area

                anchors.fill: parent

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    if (!ctx || width <= 0 || height <= 0) return;

                    ctx.reset();

                    const n = root.points.length;
                    // A single point has no run to draw between, and a peak of
                    // zero would divide every height by nothing.
                    if (n < 2 || root.peak <= 0) return;

                    const step = width / (n - 1);
                    // Two pixels of headroom so the stroke on the tallest point
                    // is not clipped in half by the top edge.
                    const usable = Math.max(0, height - 2);

                    function px(i) { return i * step; }
                    function py(i) {
                        return height - (root.points[i] / root.peak) * usable * root.progress;
                    }

                    ctx.beginPath();
                    ctx.moveTo(px(0), py(0));
                    for (let i = 1; i < n; i++) ctx.lineTo(px(i), py(i));

                    // The fill is the same colour as the line at a tenth of its
                    // weight, so the band reads as the line's own shadow rather
                    // than as a second series.
                    ctx.lineTo(px(n - 1), height);
                    ctx.lineTo(px(0), height);
                    ctx.closePath();
                    ctx.fillStyle = Qt.rgba(root.fill.r, root.fill.g, root.fill.b, 0.18);
                    ctx.fill();

                    ctx.beginPath();
                    ctx.moveTo(px(0), py(0));
                    for (let i = 1; i < n; i++) ctx.lineTo(px(i), py(i));
                    ctx.lineWidth = 2;
                    ctx.lineJoin = "round";
                    ctx.strokeStyle = root.fill;
                    ctx.stroke();
                }
            }

            // The marker rides the curve at whichever point is hovered. It is a
            // sibling of the Canvas rather than part of the paint so that
            // moving the pointer costs a translation instead of a redraw of the
            // whole series.
            Rectangle {
                width: 7
                height: 7
                radius: 3.5
                color: root.fill
                border.width: 2
                border.color: Colors.claudeCardBg
                visible: root.hoverIndex >= 0 && root.count > 1 && root.peak > 0
                x: (root.count > 1 ? root.hoverIndex * (plot.width / (root.count - 1)) : 0) - width / 2
                y: (root.peak > 0 && root.hoverIndex >= 0
                    ? plot.height - (root.points[root.hoverIndex] / root.peak)
                                    * Math.max(0, plot.height - 2)
                    : 0) - height / 2
            }

            // One strip of hit areas over the plot, so the pointer selects the
            // nearest sample rather than having to find a two-pixel line.
            RowLayout {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: root.model ?? []

                    MouseArea {
                        id: hit

                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                        onEntered: root.hoverIndex = hit.index
                        onExited: if (root.hoverIndex === hit.index) root.hoverIndex = -1
                    }
                }
            }
        }

        // Held even while empty, for the reason ClaudeBarChart's caption is:
        // a row that appears on hover resizes the chart under the pointer.
        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 15
            text: {
                if (root.hoverIndex < 0 || root.hoverIndex >= root.points.length) return "";
                const l = root.labelAt(root.hoverIndex);
                const v = root.formatted(root.points[root.hoverIndex]);
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
