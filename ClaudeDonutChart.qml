import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Config
import "ClaudeSeries.js" as Series

// A ring, not a pie: the hole is where the total goes, which is the figure
// every one of these wedges is a share of. QtQuick.Shapes draws it --
// PathAngleArc is the arc primitive Qt Quick never had outside Canvas, and
// unlike Canvas its geometry is real QML properties, so a Behavior on
// sweepAngle eases a wedge to its new share on the scene graph instead of a
// requestPaint() snapping it there every refresh.
Item {
    id: root

    property var model: []
    property string valueKey: ""
    property string labelKey: ""
    property int slices: 6
    property real thickness: 14

    property string centerTop
    property string centerBottom

    readonly property var rows: Series.collapse(root.model ?? [], root.valueKey,
                                                root.labelKey, root.slices)
    readonly property real total: Series.total(root.rows)

    // One angle pair per wedge, computed once here rather than inline in each
    // delegate below, so every wedge and the legend beside it are reading the
    // same walk of the same rows.
    //
    // Twelve o'clock, not three: a ring read clockwise from the top is the
    // convention every dashboard the reader has ever seen uses. PathAngleArc
    // already measures clockwise from three o'clock, so -90 is the rotation
    // that puts zero at the top.
    readonly property var wedges: {
        const out = [];
        if (root.total <= 0) return out;

        let at = -90;
        for (let i = 0; i < root.rows.length; i++) {
            const row = root.rows[i];
            // Capped the same way the track below is: a single row that owns
            // the whole total would otherwise sweep exactly 360 and meet
            // itself at the seam it started from.
            const sweep = Math.min((row.value / root.total) * 360, 359.99);
            out.push({
                start: at,
                sweep: sweep,
                color: Colors.claudeSeries[row.colorIndex % Colors.claudeSeries.length]
            });
            at += sweep;
        }
        return out;
    }

    implicitHeight: 132

    Shape {
        id: ring

        anchors.centerIn: parent
        // Square, and never taller than the item: the ring has to leave room
        // for the two lines of text sitting inside it.
        width: Math.max(0, Math.min(root.width, root.height))
        height: width

        // Confirmed against this build's Qt (qt6-qtdeclarative 6.11.2, well
        // past the 6.6 the curve renderer needs): it rasterises the arc's own
        // curvature instead of tessellating it into flat segments, which is
        // the difference between a smooth ring and a faceted one at this
        // stroke width. No version guard beyond that check -- there is no
        // declarative way to ask a Shape "if this renderer is missing, use
        // the old one", so the fallback is simply not reaching for a renderer
        // this build doesn't have.
        preferredRendererType: Shape.CurveRenderer

        readonly property real ringRadius: Math.max(0, ring.width / 2 - root.thickness / 2 - 1)

        // The empty track, drawn first and always, so a model that has not
        // arrived yet reads as a ring waiting to be filled rather than as a
        // blank card. Swept to 359.99 rather than a full 360: an angle arc
        // closed exactly at the point it started leaves a hairline seam on
        // some rasterisers, where a sweep one hundredth of a degree short of
        // the full circle does not, and the gap is well under a pixel.
        ShapePath {
            strokeWidth: root.thickness
            strokeColor: Colors.claudeTrack
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                // Undocumented by default, PathAngleArc connects its start to
                // whatever the path's previous point was -- here, nothing --
                // which without this would draw a stray spoke in from the
                // Shape's origin before the arc itself begins.
                moveToStart: true
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.ringRadius
                radiusY: ring.ringRadius
                startAngle: -90
                sweepAngle: 359.99
            }
        }

        // A count, not the `rows` array itself: `rows` is rebuilt whenever a
        // single figure moves, and a Repeater handed the array itself would
        // throw every wedge away and redraw it at its new angle on each
        // refresh instead of letting the angle travel there -- the same
        // device ClaudeBarChart's bars and ClaudeAreaChart's hit-strip use
        // for the same reason. A wedge count only changes when the number of
        // rows collapse() hands back does, not on every value tick.
        //
        // Each delegate is its own Shape rather than a bare ShapePath: a
        // ShapePath is a QQuickPath, not an Item, and Repeater only parents
        // Item delegates -- anything else is dropped with a warning. Nesting
        // a Shape per wedge, each holding one static ShapePath, is the
        // supported way to get a dynamic count of paths onto one ring.
        Repeater {
            model: root.wedges.length

            Shape {
                id: wedgeShape

                required property int index

                readonly property var w: root.wedges[wedgeShape.index]

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: root.thickness
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    strokeColor: wedgeShape.w.color

                    Behavior on strokeColor { ColorAnimation { duration: Motion.fast } }

                    PathAngleArc {
                        moveToStart: true
                        centerX: ring.width / 2
                        centerY: ring.height / 2
                        radiusX: ring.ringRadius
                        radiusY: ring.ringRadius
                        startAngle: wedgeShape.w.start
                        sweepAngle: wedgeShape.w.sweep

                        // The payoff of this port: a wedge that grows or
                        // shrinks on a refresh now travels to its new share
                        // instead of the ring redrawing itself instantly,
                        // which is all Canvas could ever do here. A Behavior
                        // does not replay on the value a binding starts with,
                        // only on what it becomes afterwards, so a freshly
                        // opened panel still shows its figures immediately --
                        // nothing sweeps up from empty on every open the way
                        // the old 0->1 paint scale once did.
                        Behavior on startAngle {
                            NumberAnimation { duration: Motion.base; easing.type: Motion.standard }
                        }
                        Behavior on sweepAngle {
                            NumberAnimation { duration: Motion.base; easing.type: Motion.standard }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        Text {
            text: root.centerTop
            color: Colors.claudeTitle
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeTitle
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: root.centerBottom
            color: Colors.claudeMeta
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeBody
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
            visible: text !== ""
        }
    }
}
