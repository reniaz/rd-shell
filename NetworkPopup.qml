import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Config
import qs.Services

// What is actually moving over the link behind the bar's network pill. The pill
// answers "am I online and on which connection"; this card answers "and is
// anything coming down it", which is the question asked of a bar when a download
// is either finished or stuck. The card and the click-outside dismissal both
// belong to BarPopup, which now sits the card flush against the island above
// instead of pointing a notch back up at the pill -- a notch would have had
// to be drawn inside that island itself, in a second translucent window,
// where two glass surfaces over one another double-composite into a seam
// rather than a pointer. What is left here is the reading itself.
BarPopup {
    id: root

    namespace: "qs-network"
    popupWidth: 320
    popupHeight: body.implicitHeight + 28

    // The link is only sampled while somebody is looking at it. The counters
    // live in the kernel and cost nothing to leave alone, and the pill has no
    // use for a rate, so a timer running while this card is shut would be a
    // timer running for no one. What survives the close is the history and the
    // last rates, which the service holds: shutting the card pauses the graph
    // rather than emptying it.
    //
    // Stopped on `open` and not on the window's own lifetime, because the window
    // outlives its exit animation -- a card being played back into the icon has
    // no business still reading files.
    Timer {
        // A second is the rate this card is read at. The exception is a link
        // nothing is known about yet -- a first-ever open, or an interface that
        // just changed underneath us -- where the first pair of samples is
        // taken closer together so the card has something true to show sooner
        // than a second from now. SysMon primes its CPU percentages the same
        // way and for the same reason.
        interval: Network.sampled ? 1000 : 400
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: Network.sample()
    }

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Caelus.spaceEdge
        spacing: Caelus.spaceWide

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.space

            Text {
                text: Network.wired ? "lan" : Network.connected ? "wifi" : "wifi_off"
                color: Colors.popupAccent
                font.family: Caelus.symbolFamily
                font.pixelSize: 16
            }

            Text {
                text: "Network"
                color: Colors.networkTitle
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLead
            }

            Item { Layout.fillWidth: true }

            // The connection's own name, which is the one thing here that a
            // person chose rather than the kernel: "Wired connection 1", or the
            // SSID on wifi.
            Text {
                Layout.maximumWidth: 150
                text: Network.connected ? Network.name : "Offline"
                color: Colors.networkMeta
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        // Two directions, written once. The model is deliberately two names and
        // not two objects holding the live numbers: an array rebuilt whenever a
        // rate changes is a new model every second, and a Repeater handed a new
        // model throws its delegates away and builds them again -- which would
        // restart the meter animations below on every single tick.
        Repeater {
            model: ["down", "up"]

            ColumnLayout {
                id: flow

                required property string modelData

                readonly property bool down: flow.modelData === "down"
                readonly property real rate: flow.down ? Network.rxRate : Network.txRate
                readonly property real total: flow.down ? Network.rxTotal : Network.txTotal
                readonly property color tint: flow.down ? Colors.networkDown : Colors.networkUp

                // The share of the shared peak this direction is drawing, eased
                // here and not on the width of the meter drawn from it. The
                // track below is a Layout.fillWidth child, and a layout hands
                // out its children's geometry on its first polish pass -- after
                // this delegate is complete and its Behaviors are already
                // watching. A Behavior on the width would take that first
                // assignment for a change, so a card reopened onto a link
                // already at 40M/s would sweep up to it from nothing anyway,
                // which is the one thing this card was written not to do.
                // Animating the reading keeps the opening frame true and keeps
                // the easing for the ticks that genuinely move.
                property real fraction: Math.min(1, Math.max(0, flow.rate) / Network.peak)

                Behavior on fraction {
                    NumberAnimation { duration: Motion.slow; easing.type: Motion.standard }
                }

                Layout.fillWidth: true
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    Text {
                        text: flow.down ? "arrow_downward" : "arrow_upward"
                        color: flow.tint
                        font.family: Caelus.symbolFamily
                        font.pixelSize: Caelus.sizeLead
                    }

                    Text {
                        text: flow.down ? "Down" : "Up"
                        color: Colors.networkBody
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeBody
                    }

                    Text {
                        text: Format.rate(flow.rate)
                        color: flow.tint
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeLead
                    }

                    Item { Layout.fillWidth: true }

                    // The counter itself rather than anything derived from it.
                    // It is what the kernel has added up since the interface
                    // came up, which on a machine left on is "this boot".
                    Text {
                        text: Format.human(flow.total) + " total"
                        color: Colors.networkMeta
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeBody
                    }
                }

                // Both meters are drawn against the service's single peak, so
                // the upload bar is short when the upload is small instead of
                // being scaled up to match the download beside it.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: Caelus.radiusPill
                    color: Colors.networkTrack

                    // Follows the track exactly and instantly: the easing that
                    // makes a new reading read as the link moving rather than
                    // as the card redrawing lives on `fraction` above.
                    Rectangle {
                        width: Math.round(parent.width * flow.fraction)
                        height: parent.height
                        radius: parent.radius
                        color: flow.tint
                    }
                }
            }
        }

        // The shape of the last minute, which is what tells a steady download
        // from one that is stalling. No time axis: while the card is shut
        // nothing is sampled, so the series is the last sixty readings and not
        // the last sixty seconds, and a scale claiming otherwise would be a lie
        // on every re-open.
        //
        // History updates on a one-second Timer for as long as this card is
        // open (see above), so unlike ClaudeAreaChart's curve this one is
        // never at rest -- no flash-on-refresh here, since flashing on every
        // tick would read as a flicker rather than as a signal that something
        // changed. The geometry below simply follows the reading the same way
        // Canvas's requestPaint() used to, just without having to ask for it.
        Item {
            id: sparkWrap

            Layout.fillWidth: true
            // Its own implicit height, the same way the rules above ask for
            // their single pixel: the card is sized from what this column adds
            // up to, and neither a Shape nor an Item has a natural one to
            // contribute on its own.
            implicitHeight: 44

            // A plain rule rather than a stroked path: a straight horizontal
            // line has no curve for Shapes to earn, and every other 1px
            // separator in this popup is already drawn this way.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: 1
                color: Colors.networkTrack
            }

            Shape {
                id: spark

                anchors.fill: parent
                // See ClaudeDonutChart.qml for why this is safe on this
                // build's Qt (6.11.2) and needs no declarative fallback.
                preferredRendererType: Shape.CurveRenderer

                readonly property var samples: Network.history
                readonly property int n: spark.samples.length

                // Stepped by the width the history will eventually fill
                // rather than by what it holds now, so the line grows in
                // from the right as the minute fills. Scaled to what it
                // holds, it would be stretched across the whole card from
                // the second sample on and re-stretched on every tick after.
                readonly property real step: Network.historyMax > 1
                    ? spark.width / (Network.historyMax - 1) : 0
                readonly property real x0: spark.width - (spark.n - 1) * spark.step
                // Two pixels of headroom so the stroke on the tallest sample
                // is not clipped in half by the top edge.
                readonly property real usable: Math.max(0, spark.height - 2)

                function seriesPoints(key) {
                    // One point has no run to draw between; `peak` is floored
                    // well above zero in Network.qml, but guarded here too
                    // since this is the one place that would divide by it.
                    if (spark.n < 2 || Network.peak <= 0
                        || spark.width <= 0 || spark.height <= 0) return [];

                    const pts = [];
                    for (let i = 0; i < spark.n; i++) {
                        const y = spark.height - (spark.samples[i][key] / Network.peak) * spark.usable;
                        pts.push(Qt.point(spark.x0 + i * spark.step, y));
                    }
                    return pts;
                }

                readonly property var rxPoints: spark.seriesPoints("rx")
                readonly property var txPoints: spark.seriesPoints("tx")

                // The line's points plus two more along the floor, closing
                // back under the first -- the same closing edge
                // ClaudeAreaChart's fill uses, for the same reason.
                readonly property var rxFillPoints: {
                    const line = spark.rxPoints;
                    if (line.length === 0) return [];
                    const last = line[line.length - 1];
                    const pts = line.slice();
                    pts.push(Qt.point(last.x, spark.height));
                    pts.push(Qt.point(line[0].x, spark.height));
                    return pts;
                }

                // Download is the series with the area under it: it is the
                // one that carries the weight on a home link, and a second
                // filled band would hide whichever of the two happened to be
                // smaller.
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: Qt.rgba(Colors.networkDown.r, Colors.networkDown.g,
                                        Colors.networkDown.b, 0.18)

                    PathPolyline { path: spark.rxFillPoints }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colors.networkDown
                    strokeWidth: 2
                    joinStyle: ShapePath.RoundJoin
                    // Flat, matching Canvas's own default lineCap, which this
                    // path never overrode.
                    capStyle: ShapePath.FlatCap

                    PathPolyline { path: spark.rxPoints }
                }

                // Drawn last so the quieter direction is never buried under the
                // busy one's fill.
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colors.networkUp
                    strokeWidth: 2
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.FlatCap

                    PathPolyline { path: spark.txPoints }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        // What the kernel calls the link, and what kind of link it is. Printed
        // last because it is the part that never changes while the card is open:
        // everything above it is a number being watched, and this is the label
        // on the thing being watched.
        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.space

            Text {
                Layout.fillWidth: true
                text: Network.device !== "" ? Network.device : "--"
                color: Colors.networkBody
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
                elide: Text.ElideRight
            }

            Text {
                text: Network.wired ? "Ethernet" : Network.connected ? "Wi-Fi" : ""
                color: Colors.networkMeta
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
            }
        }
    }
}
