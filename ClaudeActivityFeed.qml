import QtQuick
import qs.Config
import qs.Services

// The last few tool calls, drawn as a feed rather than a list: the rail down
// the left is what makes a stack of names read as one sequence of work.
Item {
    id: root

    property var entries: []

    readonly property int lineHeight: 20
    readonly property real railX: 5

    implicitHeight: lines.implicitHeight

    // Stops at the first and last dot instead of running the full height, so it
    // never dangles past either end of the feed.
    Rectangle {
        x: root.railX
        y: root.lineHeight / 2
        width: 1
        height: Math.max(0, lines.height - root.lineHeight)
        color: Colors.claudeDim
        visible: root.entries.length > 1
    }

    // Tool calls span three orders of magnitude, so one format cannot serve
    // them all: a 340ms read and a 4-minute build both have to stay legible.
    function span(ms) {
        const n = ms ?? 0;
        if (n <= 0) return "";
        if (n < 1000) return n + "ms";
        if (n < 60000) return (n / 1000).toFixed(1) + "s";
        return Math.floor(n / 60000) + "m" + Math.round((n % 60000) / 1000) + "s";
    }

    Column {
        id: lines

        anchors.left: parent.left
        anchors.right: parent.right

        Repeater {
            model: root.entries

            Item {
                id: line

                required property var modelData
                readonly property var e: line.modelData

                width: lines.width
                height: root.lineHeight

                Rectangle {
                    x: root.railX - 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: 3.5
                    // The in-flight call is the only one worth a colour; the
                    // rest are history and sit on the rail's own weight.
                    color: line.e.running ? Colors.claudeBusy : Colors.claudeDim
                }

                Text {
                    id: nameText

                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: line.e.name
                    color: line.e.running ? Colors.claudeBusy : Colors.claudeBody
                    font.family: "caelusevka"
                    font.pixelSize: 13
                }

                Text {
                    anchors.left: nameText.right
                    anchors.leftMargin: 8
                    anchors.right: durText.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: line.e.target
                    color: Colors.claudeMeta
                    font.family: "caelusevka"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    id: durText

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: line.e.running ? "running" : root.span(line.e.durationMs)
                    color: line.e.running ? Colors.claudeBusy : Colors.claudeMeta
                    font.family: "caelusevka"
                    font.pixelSize: 12
                }
            }
        }
    }
}
