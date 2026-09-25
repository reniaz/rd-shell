import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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

    // Resolved once per model change rather than per frame: QtQuick.Shapes
    // recomputes the curve's geometry the instant `points` changes, so this
    // is now the only place the payload is walked, where Canvas used to
    // re-parse the same numbers on every hover and every resize as well.
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

    implicitHeight: 96

    // Guards the flash below against firing on the panel's own creation --
    // see the comment on `refresh` for why that matters. Set once, after the
    // component (and every property it starts with) is already settled.
    property bool ready: false
    Component.onCompleted: root.ready = true

    // A data change still has to say so somehow: the curve itself cannot
    // tween into a new shape (see the comment on `linePoints` below for why),
    // so a brief dip and recovery stands in for the per-point animation a
    // fixed-length series could have had. Guarded so a freshly opened panel
    // shows its curve immediately rather than flashing on arrival.
    onPointsChanged: if (root.ready) refresh.restart()

    ColumnLayout {
        anchors.fill: parent
        spacing: Caelus.spaceTight

        Item {
            id: plot

            Layout.fillWidth: true
            Layout.fillHeight: true

            Shape {
                id: area

                anchors.fill: parent

                // See ClaudeDonutChart.qml for why this is safe on this build
                // (Qt 6.11.2) and why there is no declarative fallback branch
                // needed when it is.
                preferredRendererType: Shape.CurveRenderer

                SequentialAnimation {
                    id: refresh
                    PropertyAction { target: area; property: "opacity"; value: 0.35 }
                    NumberAnimation {
                        target: area
                        property: "opacity"
                        to: 1
                        duration: Motion.base
                        easing.type: Motion.standard
                    }
                }

                // PathPolyline takes its whole run as one array write, and the
                // run's length is not fixed -- seven days on one tab, thirty
                // on another -- so there is no fixed set of per-point
                // properties a Behavior could ease between two different
                // lengths. What moves is the shape as a whole, once, via the
                // opacity flash above; individual points snap, same as they
                // did under Canvas, just without a requestPaint() to drive it.
                readonly property var linePoints: {
                    const n = root.points.length;
                    // A single point has no run to draw between, and a peak of
                    // zero would divide every height by nothing.
                    if (n < 2 || root.peak <= 0 || area.width <= 0 || area.height <= 0) return [];

                    const step = area.width / (n - 1);
                    // Two pixels of headroom so the stroke on the tallest
                    // point is not clipped in half by the top edge.
                    const usable = Math.max(0, area.height - 2);

                    const pts = [];
                    for (let i = 0; i < n; i++) {
                        const y = area.height - (root.points[i] / root.peak) * usable;
                        pts.push(Qt.point(i * step, y));
                    }
                    return pts;
                }

                // The line's points plus two more that walk back along the
                // floor to under the first one -- the fill's own closing edge
                // -- which Shape then closes back up to the first point for
                // free once fillColor is set.
                readonly property var fillPoints: {
                    const line = area.linePoints;
                    if (line.length === 0) return [];
                    const last = line[line.length - 1];
                    const pts = line.slice();
                    pts.push(Qt.point(last.x, area.height));
                    pts.push(Qt.point(line[0].x, area.height));
                    return pts;
                }

                // The fill is the same colour as the line at a tenth of its
                // weight, so the band reads as the line's own shadow rather
                // than as a second series.
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: Qt.rgba(root.fill.r, root.fill.g, root.fill.b, 0.18)

                    Behavior on fillColor { ColorAnimation { duration: Motion.fast } }

                    PathPolyline { path: area.fillPoints }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.fill
                    strokeWidth: 2
                    joinStyle: ShapePath.RoundJoin
                    // Flat, matching Canvas's own default lineCap, which this
                    // path never overrode.
                    capStyle: ShapePath.FlatCap

                    Behavior on strokeColor { ColorAnimation { duration: Motion.fast } }

                    PathPolyline { path: area.linePoints }
                }
            }

            // The marker rides the curve at whichever point is hovered. It is a
            // sibling of the Shape rather than part of its geometry so that
            // moving the pointer costs a translation instead of rebuilding the
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
                    // A count rather than the array: replacing the array
                    // rebuilds every delegate, and a hit area rebuilt under the
                    // pointer never sends the `entered` that keeps the caption
                    // on the sample being read.
                    model: root.count

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
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeBody
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
