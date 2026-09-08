import QtQuick
import qs.Config
import qs.Services

// One session: a 30px table row, plus the drawer that slides its dashboard out
// underneath. Nothing here measures text -- every x comes from `cols`.
Item {
    id: root

    // One required property per role rather than the whole row object. A
    // required property named `model` is filled from the role of that name --
    // the delegate machinery resolves roles first -- so the LLM name arrives
    // here as plain `model` and there is no model object to reach through.
    required property int index
    required property string sessionId
    required property string project
    required property string name
    required property string cwd
    required property string window
    required property string state
    required property string waitingFor
    // Epoch milliseconds overflow an int, so this role stays real all the way
    // down; ClaudeSession says the same where it builds the row.
    required property real statusSince
    required property int ctxPct
    required property int ctxTokens
    required property int ctxLimit
    required property string toolName
    required property string toolTarget
    required property string model
    required property string mode
    required property string effort
    required property string branch
    required property string title
    required property string lastPrompt
    required property int subagents
    required property string planName
    required property int planDone
    required property int planOpen

    property ClaudeColumns cols

    readonly property bool expanded: ClaudeDetail.sessionId === root.sessionId
    readonly property bool waiting: root.waitingFor !== ""
    readonly property bool busy: root.state === "busy"

    // One colour drives the glyph, the state word and the stripe, so a blocked
    // row cannot half-announce itself.
    readonly property color tone: root.waiting ? Colors.claudeAttention
        : root.busy ? Colors.claudeBusy
        : Colors.claudeIdle

    readonly property string activityText: {
        if (root.waiting) return root.waitingFor;
        if (root.busy) {
            const what = root.toolName !== "" ? root.toolName : "thinking";
            const el = ClaudeSession.elapsed(root.statusSince);
            return el !== "" ? what + "  ·  " + el : what;
        }
        if (root.lastPrompt !== "") return "\"" + root.lastPrompt + "\"";
        return root.title;
    }

    // Flipped one turn after creation. Without it, a row that is already
    // expanded when it scrolls back into view replays the whole open animation
    // from zero every single time it reappears.
    property bool ready: false

    // Re-armed once when the first transcript payload lands, because the drawer
    // grows again then -- but only once, or every 5s refresh would yank a list
    // the user had deliberately scrolled back under the open row.
    property bool settled: false

    width: root.ListView.view ? root.ListView.view.width : 0

    // implicitHeight and nothing else. Binding `height` as well makes ListView
    // stop honouring implicitHeight, which freezes the row at its collapsed
    // size while the drawer paints straight over the row below it.
    implicitHeight: root.cols.rowHeight + drawer.height

    Component.onCompleted: Qt.callLater(() => root.ready = true)

    onExpandedChanged: {
        root.settled = false;
        if (root.expanded) settle.restart();
    }

    // A plain Timer and not the height Behavior's onFinished: inside a Behavior
    // that signal does not fire reliably, which Services/ClaudeSession.qml:190
    // already documents for the panel release. Running it immediately instead
    // would measure the row at its pre-animation height and scroll to the wrong
    // place entirely.
    Timer {
        id: settle
        interval: 190
        onTriggered: if (root.ListView.view) root.ListView.view.positionViewAtIndex(root.index, ListView.Contain)
    }

    Connections {
        target: ClaudeDetail

        function onDataChanged() {
            if (!root.expanded || root.settled) return;
            root.settled = true;
            settle.restart();
        }
    }

    Rectangle {
        id: rowBody

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.cols.rowHeight
        radius: 8
        color: root.expanded || hover.hovered ? Colors.claudeCardBg : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        HoverHandler { id: hover }

        // A session blocked on a human has to be findable without reading a
        // single word of the row.
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: root.cols.stripeWidth
            height: parent.height - 8
            radius: width / 2
            color: Colors.claudeAttention
            visible: root.waiting
        }

        Text {
            id: glyph

            x: root.cols.xGlyph
            anchors.verticalCenter: parent.verticalCenter
            width: root.cols.glyphWidth
            text: root.waiting ? "pause_circle"
                : root.busy ? "radio_button_checked"
                : "radio_button_unchecked"
            color: root.tone
            font.family: "Material Symbols Rounded"
            font.pixelSize: root.cols.iconSize
            opacity: 1

            Behavior on color { ColorAnimation { duration: 120 } }

            // An opacity pulse and deliberately not a RotationAnimator: a
            // spinner on a bar that is always running keeps the compositor's
            // render loop awake for as long as any session is busy. This one
            // stops dead the moment the panel closes.
            SequentialAnimation {
                id: pulse

                running: root.busy && !root.waiting && ClaudeSession.panelOpen
                loops: Animation.Infinite

                NumberAnimation {
                    target: glyph; property: "opacity"
                    to: 0.35; duration: 700; easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: glyph; property: "opacity"
                    to: 1; duration: 700; easing.type: Easing.InOutSine
                }

                // The animation writes opacity directly, so stopping mid-cycle
                // would otherwise strand the glyph at whatever it faded to.
                onRunningChanged: if (!running) glyph.opacity = 1
            }
        }

        Text {
            x: root.cols.xProject
            anchors.verticalCenter: parent.verticalCenter
            width: root.cols.projectWidth
            text: root.project !== "" ? root.project : root.name
            color: root.expanded ? Colors.claudeAccent : Colors.claudeTitle
            font.family: "caelusevka"
            font.pixelSize: root.cols.fontSize
            elide: Text.ElideRight
        }

        Text {
            x: root.cols.xState
            anchors.verticalCenter: parent.verticalCenter
            width: root.cols.stateWidth
            text: root.waiting ? "NEEDS YOU" : root.state
            color: root.tone
            font.family: "caelusevka"
            font.pixelSize: root.cols.fontSize
            elide: Text.ElideRight
        }

        Text {
            x: root.cols.xPct
            anchors.verticalCenter: parent.verticalCenter
            width: root.cols.pctWidth
            horizontalAlignment: Text.AlignRight
            text: root.ctxPct + "%"
            color: root.ctxPct > 75 ? ClaudeSession.levelColor(root.ctxPct) : Colors.claudeMeta
            font.family: "caelusevka"
            font.pixelSize: root.cols.fontSize
        }

        ClaudeMeter {
            x: root.cols.xMeter
            anchors.verticalCenter: parent.verticalCenter
            width: root.cols.meterWidth
            thickness: 4
            fraction: root.ctxPct / 100
            // -1 keeps the inline label off, since the figure has its own
            // column immediately to the left; the fill colour therefore has to
            // be passed rather than derived from `percent`.
            percent: -1
            fill: ClaudeSession.levelColor(root.ctxPct)
        }

        // The one elastic column. Anchored to the panel edge through the shared
        // inset rather than to whatever happens to sit in the gutter, so it
        // ends on the same pixel whether or not this row has a badge.
        Text {
            anchors.left: parent.left
            anchors.leftMargin: root.cols.xActivity
            anchors.right: parent.right
            anchors.rightMargin: root.cols.rightInset
            anchors.verticalCenter: parent.verticalCenter
            text: root.activityText
            color: root.waiting ? Colors.claudeAttention
                : root.busy ? Colors.claudeBody
                : Colors.claudeMeta
            font.family: "caelusevka"
            font.pixelSize: root.cols.fontSize
            elide: Text.ElideRight
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: root.cols.padRight + root.cols.termWidth + root.cols.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            visible: root.subagents > 0

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "account_tree"
                color: Colors.claudeAgent
                font.family: "Material Symbols Rounded"
                font.pixelSize: root.cols.iconSize
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.subagents
                color: Colors.claudeAgent
                font.family: "caelusevka"
                font.pixelSize: root.cols.fontSize
            }
        }

        // Declared after every label so it sits over them, and before the
        // terminal button so the button sits over it. Swap the two and the
        // button's clicks are swallowed by the row -- the same ordering trap
        // documented at NotificationCard.qml:59-62.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            // expand() on the id that is already open collapses it, so one call
            // is the whole toggle.
            onClicked: ClaudeDetail.expand(root.sessionId)
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: root.cols.padRight
            anchors.verticalCenter: parent.verticalCenter
            width: root.cols.termWidth
            horizontalAlignment: Text.AlignRight
            text: "terminal"
            color: termArea.containsMouse ? Colors.claudeAccent : Colors.claudeMeta
            font.family: "Material Symbols Rounded"
            font.pixelSize: 16
            // Its slot in the gutter is reserved by cols.rightInset whether or
            // not this row has a window, so hiding it shifts nothing.
            visible: root.window !== ""
            opacity: hover.hovered ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 120 } }

            MouseArea {
                id: termArea

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ClaudeSession.focusWindow(root.window)
            }
        }
    }

    Item {
        id: drawer

        anchors.top: rowBody.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        height: root.expanded ? detail.implicitHeight : 0

        // Clipping every delegate permanently costs a clip node per row and
        // breaks the list's batching. It is only wanted while the drawer is
        // mid-slide and therefore shorter than what it holds.
        clip: height < detail.implicitHeight

        Behavior on height {
            enabled: root.ready
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Loader {
            id: detail

            width: parent.width

            // Deliberately not `active: root.expanded`. That rips the content
            // away on the first frame of the close, leaving implicitHeight at 0
            // so the drawer animates 0 -> 0 and simply blinks shut.
            active: root.expanded || drawer.height > 0
            sourceComponent: detailBody
        }
    }

    Component {
        id: detailBody

        ClaudeSessionDetail {
            sessionId: root.sessionId
            cwd: root.cwd
            state: root.state
            waitingFor: root.waitingFor
            statusSince: root.statusSince
            toolName: root.toolName
            toolTarget: root.toolTarget
            modelName: root.model
            mode: root.mode
            effort: root.effort
            branch: root.branch
            ctxTokens: root.ctxTokens
            ctxLimit: root.ctxLimit
            ctxPct: root.ctxPct
            planName: root.planName
            planDone: root.planDone
            planOpen: root.planOpen
        }
    }
}
