import QtQuick
import Qt.labs.qmlmodels
import qs.Config
import qs.Services

// The Sessions tab body: the dense table, and nothing else. Every row it holds
// reads its geometry off the one ClaudeColumns below, which is the whole reason
// the columns line up.
Item {
    id: root

    // The table's own height, so the panel can be as short as the session count
    // rather than as tall as the screen. The empty-state line is a fixed 40 for
    // the same reason: "No live sessions" is still something to be sized to.
    // Deliberately not implicitHeight: the panel sizes itself from this, and a
    // value the enclosing layout also feeds back into would settle at zero.
    readonly property real naturalHeight: list.count === 0 ? 40 : list.contentHeight

    ClaudeColumns { id: tableCols }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 20
        text: "No live sessions"
        color: Colors.claudeMeta
        font.family: "caelusevka"
        font.pixelSize: 14
        visible: list.count === 0
    }

    // A zero-interval timer rather than a direct call: the model reconciles in
    // place, so one 2s poll can emit dataChanged once per touched role on every
    // row it touched, and the columns only need measuring once per frame.
    Timer {
        id: remeasure
        interval: 0
        onTriggered: tableCols.measure(ClaudeSession.rows)
    }

    Component.onCompleted: remeasure.restart()

    Connections {
        target: ClaudeSession.rows

        function onCountChanged() { remeasure.restart(); }
        function onDataChanged() { remeasure.restart(); }
    }

    ListView {
        id: list

        anchors.fill: parent
        clip: true
        spacing: 2
        // Every row exists whatever height the view is given, so contentHeight
        // is a property of the session list and not of the panel wrapped around
        // it -- which is what lets the panel size itself from it.
        cacheBuffer: 100000
        model: ClaudeSession.rows
        boundsBehavior: Flickable.StopAtBounds

        // reuseItems is deliberately left off. A pooled delegate carries its
        // `ready` flag and its open drawer height into whatever row it is
        // recycled as, so a freshly scrolled-in row would arrive already
        // expanded and skip its own animation.

        delegate: DelegateChooser {
            role: "rowType"

            DelegateChoice {
                roleValue: "job"

                ClaudeJobRow { cols: tableCols }
            }

            // No roleValue: the fallback choice, which is every session row.
            DelegateChoice {
                ClaudeSessionRow { cols: tableCols }
            }
        }
    }
}
