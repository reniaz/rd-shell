import QtQuick
import QtQuick.Layouts
import qs.Config
import "ClaudeSeries.js" as Series

// A ring, not a pie: the hole is where the total goes, which is the figure
// every one of these wedges is a share of. Drawn on a Canvas because Qt Quick
// has no arc primitive and a ring built from rotated Rectangles cannot be
// given a rounded cap or an accurate sweep.
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

    // Canvas cannot be animated by a Behavior, so the sweep is driven by an
    // explicit 0..1 that the paint multiplies into every angle. It runs once,
    // on creation, which is the only moment the ring is new to the eye.
    property real progress: 0

    implicitHeight: 132

    Component.onCompleted: sweep.start()

    NumberAnimation {
        id: sweep
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 520
        easing.type: Easing.OutCubic
    }

    // The palette is a property of a singleton, so it is read into the paint
    // through a binding the Canvas can depend on. Repainting on rows, size and
    // progress covers every input the drawing actually has.
    onRowsChanged: ring.requestPaint()
    onProgressChanged: ring.requestPaint()
    onThicknessChanged: ring.requestPaint()

    Canvas {
        id: ring

        anchors.centerIn: parent
        // Square, and never taller than the item: the ring has to leave room
        // for the two lines of text sitting inside it.
        width: Math.max(0, Math.min(root.width, root.height))
        height: width

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            if (!ctx || width <= 0 || height <= 0) return;

            ctx.reset();

            const cx = width / 2;
            const cy = height / 2;
            const r = Math.max(0, Math.min(cx, cy) - root.thickness / 2 - 1);
            if (r <= 0) return;

            ctx.lineWidth = root.thickness;
            ctx.lineCap = "butt";

            // The empty track is drawn first and always, so a model that has
            // not arrived yet reads as a ring waiting to be filled rather than
            // as a blank card.
            ctx.beginPath();
            ctx.strokeStyle = Colors.claudeTrack;
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.stroke();

            if (root.total <= 0) return;

            // Twelve o'clock, not three: a ring read clockwise from the top is
            // the convention every dashboard the reader has ever seen uses.
            let at = -Math.PI / 2;

            for (let i = 0; i < root.rows.length; i++) {
                const row = root.rows[i];
                const span = (row.value / root.total) * Math.PI * 2 * root.progress;
                if (span <= 0) continue;

                ctx.beginPath();
                ctx.strokeStyle = Colors.claudeSeries[row.colorIndex % Colors.claudeSeries.length];
                ctx.arc(cx, cy, r, at, at + span);
                ctx.stroke();

                at += span;
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        Text {
            text: root.centerTop
            color: Colors.claudeTitle
            font.family: "caelusevka"
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: root.centerBottom
            color: Colors.claudeMeta
            font.family: "caelusevka"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
            visible: text !== ""
        }
    }
}
