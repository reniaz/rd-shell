import QtQuick
import qs.Config
import qs.Services

// A background job on the same grid as the sessions around it. There is nothing
// to expand -- a job has no transcript of its own -- so this row is the table
// geometry and nothing more.
Item {
    id: root

    // One required property per role; a job row leaves the session-only roles
    // undeclared rather than carrying empty copies of them.
    required property string sessionId
    required property string state
    required property string jobDetail
    required property int jobTokens
    required property int jobTasks
    required property int jobQueued

    property ClaudeColumns cols

    readonly property bool working: root.state === "working"

    // A finished job is history that has not been cleaned up yet, so it sits
    // at the same weight as an idle session rather than competing with live work.
    readonly property color tone: root.working ? Colors.claudeBusy : Colors.claudeIdle

    width: root.ListView.view ? root.ListView.view.width : 0
    implicitHeight: root.cols.rowHeight

    HoverHandler { id: hover }

    Item {
        anchors.fill: parent

        Text {
            x: root.cols.xGlyph
            anchors.verticalCenter: parent.verticalCenter
            width: root.cols.glyphWidth
            // Deliberately none of the three circles a session uses: the glyph
            // column is where you notice this is not a session at all.
            text: root.working ? "bolt" : root.state === "done" ? "task_alt" : "pending"
            color: root.tone
            font.family: "Material Symbols Rounded"
            font.pixelSize: root.cols.iconSize
        }

        Text {
            x: root.cols.xProject
            anchors.verticalCenter: parent.verticalCenter
            width: root.cols.projectWidth
            text: root.sessionId
            color: Colors.claudeMeta
            font.family: "caelusevka"
            font.pixelSize: root.cols.fontSize
            elide: Text.ElideRight
        }

        Text {
            x: root.cols.xState
            anchors.verticalCenter: parent.verticalCenter
            width: root.cols.stateWidth
            text: root.state
            color: root.tone
            font.family: "caelusevka"
            font.pixelSize: root.cols.fontSize
            elide: Text.ElideRight
        }

        // A job has no context window, so its two numeric columns are spent on
        // the one figure it does have, right-aligned to where the meter ends.
        Text {
            x: root.cols.xPct
            anchors.verticalCenter: parent.verticalCenter
            width: root.cols.xMeter + root.cols.meterWidth - root.cols.xPct
            horizontalAlignment: Text.AlignRight
            text: root.jobTokens > 0 ? ClaudeSession.compact(root.jobTokens) : ""
            color: Colors.claudeMeta
            font.family: "caelusevka"
            font.pixelSize: root.cols.fontSize
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: root.cols.xActivity
            anchors.right: parent.right
            anchors.rightMargin: root.cols.rightInset
            anchors.verticalCenter: parent.verticalCenter
            text: root.jobQueued > 0
                ? root.jobQueued + " queued  ·  " + root.jobDetail
                : root.jobDetail
            color: Colors.claudeMeta
            font.family: "caelusevka"
            font.pixelSize: root.cols.fontSize
            elide: Text.ElideRight
        }

        // The same gutter slot a session spends on its subagent count, holding
        // the equivalent figure for a job.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: root.cols.padRight + root.cols.termWidth + root.cols.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            visible: root.jobTasks > 0

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "checklist"
                color: Colors.claudeAgent
                font.family: "Material Symbols Rounded"
                font.pixelSize: root.cols.iconSize
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.jobTasks
                color: Colors.claudeAgent
                font.family: "caelusevka"
                font.pixelSize: root.cols.fontSize
            }
        }

        // The gutter slot a session row spends on its terminal button. Only a
        // finished job offers it: dismissing one deletes its directory, which
        // for a job still working would be pulling the floor out from under it.
        Text {
            anchors.right: parent.right
            anchors.rightMargin: root.cols.padRight
            anchors.verticalCenter: parent.verticalCenter
            width: root.cols.termWidth
            horizontalAlignment: Text.AlignRight
            text: "delete"
            color: rmArea.containsMouse ? Colors.claudeCritical : Colors.claudeMeta
            font.family: "Material Symbols Rounded"
            font.pixelSize: 16
            visible: root.state === "done"
            opacity: hover.hovered ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 120 } }

            MouseArea {
                id: rmArea

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ClaudeSession.dismissJob(root.sessionId)
            }
        }
    }
}
