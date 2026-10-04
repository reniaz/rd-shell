import QtQuick
import qs.Config

// Material 3 Expressive's wavy progress indicator. The filled portion draws
// as a sine-offset stroke whose amplitude eases to 0 at its own two ends --
// the start of the track and the boundary where it meets the gap -- so a
// short fill (value near empty) sits almost entirely inside that taper and
// reads as nearly flat, while a long fill (value near full) carries the wave
// through its middle and only flattens right at the very tip. The unfilled
// remainder is a plain straight stroke, split from the fill by the small M3
// gap. Canvas, as the idea named, not Shape/PathPolyline: a hand-stepped
// sine polyline is simpler to taper per-sample than coercing a Shape's path
// into the same per-point amplitude ease.
//
// NOTE on "rings": BrightnessOsd.qml and AudioOsd.qml have never drawn a
// circular level meter -- see the Rectangle track+fill this file replaces in
// both. M3 itself has a "wavy linear" form for exactly that shape, so this
// draws that, along the OSDs' existing horizontal track, rather than
// inventing a circular mode nothing in this shell ever had or asked to keep.
Item {
    id: root

    // 0..1. Same convention the old fill Rectangle read off `track.width *
    // fraction` -- callers pass `root.fraction` / `root.level` straight
    // through.
    property real value: 0
    property color trackColor
    property color fillColor
    // Mirrors the Rectangle this replaces, which hardcoded the same bare 5
    // (`implicitHeight: 5`) in both OSDs -- carried forward, not a new
    // design literal.
    property real thickness: 5
    // The caller binds this to OsdCard's own `shown`, not to Qt's `visible`:
    // the card's content stays `visible: true` through its fade-out (only
    // opacity/scale move), so a Timer gated on `visible` would keep ticking
    // for the length of that fade. Gated on `shown` instead, the wave's
    // phase only advances for the second and a half the card is actually
    // legible -- at rest this costs one idle Timer plus whatever the last
    // Canvas paint already drew, nothing more.
    property bool running: true

    Behavior on value {
        // Same duration/easing the Rectangle fill animated `width` with --
        // swapping this in changes how the value is drawn, not how it moves.
        NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
    }

    implicitHeight: Math.ceil(root.thickness + 2 * root._amplitude + 2)

    // ── tuned by eye, deliberately small so the wave reads as an M3 detail
    // next to the percentage text, not as noise. Motion.qml's wave-token
    // slot (if this round adds one) belongs to the ripple agent, not here --
    // see CONTRACT-4.md -- so these stay local constants. ──
    readonly property real _wavelength: 16
    readonly property real _amplitude: Math.min(1.6, root.thickness * 0.4)
    readonly property real _easeLen: root._wavelength * 0.65
    // M3's gap between the wavy fill and the plain remainder is roughly one
    // track-thickness of breathing room.
    readonly property real _gap: root.thickness
    // Crawl speed in px/second at the wave's own scale -- slow enough that
    // an OSD's second-and-a-half on screen reads as "alive" rather than as a
    // marquee competing with the number beside it.
    readonly property real _speedPxPerSec: 6

    property real _phase: 0

    Timer {
        id: phaseTimer
        interval: 50
        repeat: true
        // `root.width > 0` guards the one frame before layout has run, where
        // a tick would advance the phase with nothing yet to repaint.
        // `root.visible` is deliberate: the OSDs keep this item instantiated
        // and only hide it when "Wavy OSD progress" is off, and an invisible
        // Canvas repainted every 50ms is pure waste.
        running: root.running && root.visible && root.width > 0
        onTriggered: {
            root._phase += (2 * Math.PI / root._wavelength) * root._speedPxPerSec * (interval / 1000)
            canvas.requestPaint()
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        // `Screen` is an attached type reachable only once `root` is parented
        // into a window; falls back to 1 before that, the same guard
        // Blob.qml's own `uDpr` uses for the same reason.
        readonly property real dpr: root.Screen.devicePixelRatio > 0 ? root.Screen.devicePixelRatio : 1
        // Backing store at the real device-pixel size; `onPaint` below draws
        // in logical units and scales the context up to match. Without this
        // a Canvas renders its backing store at the item's logical size and
        // the compositor upscales that texture to fill the HiDPI output,
        // which is exactly what reads as blur.
        canvasSize: Qt.size(Math.max(1, width * dpr), Math.max(1, height * dpr))

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            // Qt extension to the HTML5 Context2D: clears the canvas and
            // drops any transform left over from the previous paint, so the
            // `ctx.scale` below never compounds across repaints.
            ctx.reset()
            ctx.scale(dpr, dpr)

            var w = width
            var cy = height / 2
            var cap = root.thickness / 2
            var full = w * root.value
            var nearFull = root.value > 0.999
            var activeEnd = nearFull ? w : Math.max(0, full - root._gap / 2)
            var remStart = nearFull ? w : full + root._gap / 2

            ctx.lineWidth = root.thickness
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            // Inactive remainder -- plain straight stroke.
            if (w - remStart > root.thickness) {
                ctx.strokeStyle = root.trackColor
                ctx.beginPath()
                ctx.moveTo(Math.min(remStart + cap, w - cap), cy)
                ctx.lineTo(w - cap, cy)
                ctx.stroke()
            }

            // Active fill -- sine-offset, amplitude eased to 0 at both ends
            // of its own span (see the header comment on why that alone
            // already covers "near empty" and "near full").
            if (activeEnd > 0) {
                ctx.strokeStyle = root.fillColor
                ctx.beginPath()
                var len = activeEnd
                var step = 2
                var started = false
                var x
                for (x = 0; x <= len; x += step) {
                    var d = Math.min(x, len - x)
                    var t = Math.max(0, Math.min(1, d / root._easeLen))
                    var env = t * t * (3 - 2 * t) // smoothstep
                    var y = cy + root._amplitude * env * Math.sin((x / root._wavelength) * 2 * Math.PI + root._phase)
                    if (!started) { ctx.moveTo(x, y); started = true } else { ctx.lineTo(x, y) }
                }
                if (!started) {
                    // Shorter than one step: value just above 0. A
                    // near-zero-length round-capped stroke still renders as
                    // a filled dot, which is what the easing above would
                    // converge to anyway.
                    ctx.moveTo(len / 2, cy)
                    ctx.lineTo(len / 2 + 0.01, cy)
                }
                ctx.stroke()
            }
        }

        Component.onCompleted: requestPaint()
    }

    onValueChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onFillColorChanged: canvas.requestPaint()
    onThicknessChanged: canvas.requestPaint()
}
