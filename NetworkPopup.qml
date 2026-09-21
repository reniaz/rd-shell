import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// What is actually moving over the link behind the bar's network pill. The pill
// answers "am I online and on which connection"; this card answers "and is
// anything coming down it", which is the question asked of a bar when a download
// is either finished or stuck. The card, its notch and the click-outside
// dismissal all belong to BarPopup; what is left here is the reading itself.
BarPopup {
    id: root

    namespace: "qs-network"
    popupWidth: 320
    popupHeight: body.implicitHeight + 28

    // Canvas has no binding to the data it draws, so the repaint is driven from
    // a property that does -- the same device ClaudeAreaChart uses for its own
    // series.
    readonly property var samples: Network.history

    onSamplesChanged: spark.requestPaint()

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
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: Network.wired ? "lan" : Network.connected ? "wifi" : "wifi_off"
                color: Colors.popupAccent
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
            }

            Text {
                text: "Network"
                color: Colors.networkTitle
                font.family: "caelusevka"
                font.pixelSize: 15
            }

            Item { Layout.fillWidth: true }

            // The connection's own name, which is the one thing here that a
            // person chose rather than the kernel: "Wired connection 1", or the
            // SSID on wifi.
            Text {
                Layout.maximumWidth: 150
                text: Network.connected ? Network.name : "Offline"
                color: Colors.networkMeta
                font.family: "caelusevka"
                font.pixelSize: 13
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
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                Layout.fillWidth: true
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    Text {
                        text: flow.down ? "arrow_downward" : "arrow_upward"
                        color: flow.tint
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 15
                    }

                    Text {
                        text: flow.down ? "Down" : "Up"
                        color: Colors.networkBody
                        font.family: "caelusevka"
                        font.pixelSize: 13
                    }

                    Text {
                        text: Format.rate(flow.rate)
                        color: flow.tint
                        font.family: "caelusevka"
                        font.pixelSize: 15
                    }

                    Item { Layout.fillWidth: true }

                    // The counter itself rather than anything derived from it.
                    // It is what the kernel has added up since the interface
                    // came up, which on a machine left on is "this boot".
                    Text {
                        text: Format.human(flow.total) + " total"
                        color: Colors.networkMeta
                        font.family: "caelusevka"
                        font.pixelSize: 13
                    }
                }

                // Both meters are drawn against the service's single peak, so
                // the upload bar is short when the upload is small instead of
                // being scaled up to match the download beside it.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
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
        Canvas {
            id: spark

            Layout.fillWidth: true
            // Its own implicit height, the same way the rules above ask for
            // their single pixel: the card is sized from what this column adds
            // up to, and a Canvas has no natural height to contribute.
            implicitHeight: 44

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                if (!ctx || width <= 0 || height <= 0) return;

                ctx.reset();

                // Drawn whatever happens, so a card opened before a single pair
                // of samples exists reads as an empty graph and not as a gap in
                // the card. The half-pixel keeps a one-pixel rule on one row of
                // pixels instead of smearing it over two.
                ctx.beginPath();
                ctx.moveTo(0, height - 0.5);
                ctx.lineTo(width, height - 0.5);
                ctx.lineWidth = 1;
                ctx.strokeStyle = Colors.networkTrack;
                ctx.stroke();

                const s = Network.history;
                const n = s.length;
                // One point has no run to draw between.
                if (n < 2) return;

                // Stepped by the width the history will eventually fill rather
                // than by what it holds now, so the line grows in from the right
                // as the minute fills. Scaled to what it holds, it would be
                // stretched across the whole card from the second sample on and
                // re-stretched on every tick after it.
                const step = width / (Network.historyMax - 1);
                const x0 = width - (n - 1) * step;
                // Two pixels of headroom so the stroke on the tallest sample is
                // not clipped in half by the top edge.
                const usable = Math.max(0, height - 2);
                const peak = Network.peak;

                function px(i) { return x0 + i * step; }
                function py(v) { return height - (v / peak) * usable; }

                // Download is the series with the area under it: it is the one
                // that carries the weight on a home link, and a second filled
                // band would hide whichever of the two happened to be smaller.
                ctx.beginPath();
                ctx.moveTo(px(0), py(s[0].rx));
                for (let i = 1; i < n; i++) ctx.lineTo(px(i), py(s[i].rx));
                ctx.lineTo(px(n - 1), height);
                ctx.lineTo(px(0), height);
                ctx.closePath();
                const d = Colors.networkDown;
                ctx.fillStyle = Qt.rgba(d.r, d.g, d.b, 0.18);
                ctx.fill();

                ctx.lineWidth = 2;
                ctx.lineJoin = "round";

                ctx.beginPath();
                ctx.moveTo(px(0), py(s[0].rx));
                for (let i = 1; i < n; i++) ctx.lineTo(px(i), py(s[i].rx));
                ctx.strokeStyle = Colors.networkDown;
                ctx.stroke();

                // Drawn last so the quieter direction is never buried under the
                // busy one's fill.
                ctx.beginPath();
                ctx.moveTo(px(0), py(s[0].tx));
                for (let i = 1; i < n; i++) ctx.lineTo(px(i), py(s[i].tx));
                ctx.strokeStyle = Colors.networkUp;
                ctx.stroke();
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
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: Network.device !== "" ? Network.device : "--"
                color: Colors.networkBody
                font.family: "caelusevka"
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                text: Network.wired ? "Ethernet" : Network.connected ? "Wi-Fi" : ""
                color: Colors.networkMeta
                font.family: "caelusevka"
                font.pixelSize: 13
            }
        }
    }
}
