import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The expanded body of one session row. Everything live comes from
// ClaudeDetail; the handful of values the 2s poll already knows are passed down
// from the row instead, so the top half of this dashboard is already filled in
// while the transcript scan is still running.
Item {
    id: root

    property string sessionId: ""
    property string cwd: ""
    property string state: ""
    property string waitingFor: ""
    property real statusSince: 0
    property string toolName: ""
    property string toolTarget: ""
    property string modelName: ""
    property string mode: ""
    property string effort: ""
    property string branch: ""
    property int ctxTokens: 0
    property int ctxLimit: 0
    property int ctxPct: 0
    property string planName: ""
    property int planDone: 0
    property int planOpen: 0

    // The singleton already drops replies for the wrong session, but a drawer
    // that is sliding shut outlives its own expansion by a frame or two, and
    // painting the next row's numbers into it would be worse than leaving it
    // blank.
    readonly property var d: (ClaudeDetail.data && ClaudeDetail.data.sessionId === root.sessionId)
        ? ClaudeDetail.data
        : null

    readonly property var subs: root.d ? (root.d.subagents ?? []) : []
    readonly property var acts: root.d ? (root.d.activity ?? []) : []
    readonly property var econ: root.d ? (root.d.economics ?? null) : null
    readonly property var files: root.d ? (root.d.files ?? []) : []
    readonly property var git: root.d ? (root.d.git ?? null) : null
    readonly property var queue: root.d && root.d.prompt ? (root.d.prompt.queue ?? []) : []
    readonly property string promptText: root.d && root.d.prompt ? (root.d.prompt.last ?? "") : ""

    readonly property bool waiting: root.waitingFor !== ""
    readonly property bool busy: root.state === "busy"
    readonly property int subsRunning: root.subs.filter(a => a.running).length
    readonly property int planTotal: root.planDone + root.planOpen

    readonly property var chips: {
        const out = [];
        if (root.modelName !== "") out.push({ text: root.modelName, accent: true });
        if (root.effort !== "") out.push({ text: root.effort, accent: false });
        if (root.mode !== "") out.push({ text: root.mode, accent: false });
        if (root.branch !== "") out.push({ text: root.branch, accent: false });
        return out;
    }

    readonly property string subagentSummary: {
        const done = root.subs.length - root.subsRunning;
        const bits = [];
        if (root.subsRunning > 0) bits.push(root.subsRunning + " running");
        if (done > 0) bits.push(done + " done");
        return bits.join("  ·  ");
    }

    readonly property string growthText: {
        const g = root.num(root.econ, "growthPerTurn");
        if (g <= 0) return "";
        const t = root.num(root.econ, "turnsToLimit");
        const head = "≈" + ClaudeSession.compact(g) + "/turn";
        return t > 0 ? head + "  ·  ~" + t + " turns to limit" : head;
    }

    // Turns-to-limit is the number that decides whether this session is worth
    // starting another long task in, so it has to change colour before it runs
    // out rather than after.
    readonly property color growthColor: {
        const t = root.num(root.econ, "turnsToLimit");
        if (t > 0 && t <= 5) return Colors.claudeCritical;
        if (t > 0 && t <= 15) return Colors.claudeWarn;
        return Colors.claudeMeta;
    }

    // Every section binds against a payload that is null until the first scan
    // lands, so one guarded reader beats a ternary at each of thirty sites.
    function num(obj, key) {
        const v = obj ? obj[key] : 0;
        return (typeof v === "number" && isFinite(v)) ? v : 0;
    }

    // Absolute paths are long and all share a prefix that the footer already
    // prints, so against a known cwd only the tail identifies the file.
    function relative(p) {
        if (!p) return "";
        if (root.cwd !== "" && p.indexOf(root.cwd + "/") === 0) return p.slice(root.cwd.length + 1);
        return p;
    }

    function money(n) {
        return "$" + ((typeof n === "number" && isFinite(n)) ? n : 0).toFixed(2);
    }

    implicitHeight: col.implicitHeight + 14

    ColumnLayout {
        id: col

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.leftMargin: 10
        anchors.rightMargin: 2
        spacing: 8

        // Every section below hides itself when it has nothing to say, so an
        // idle session collapses to Now and a footer rather than to five empty
        // cards -- and this line covers the gap before the first scan returns.
        Text {
            Layout.fillWidth: true
            text: "reading transcript…"
            color: Colors.claudeMeta
            font.family: "caelusevka"
            font.pixelSize: 13
            visible: root.d === null
        }

        // ── now ──────────────────────────────────────────────────────────
        ClaudeSection {
            Layout.fillWidth: true
            title: "Now"
            trailing: ClaudeSession.elapsed(root.statusSince)

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: root.waiting ? "pause_circle" : root.busy ? "bolt" : "check_circle"
                    color: root.waiting ? Colors.claudeAttention
                        : root.busy ? Colors.claudeBusy
                        : Colors.claudeIdle
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 15
                }

                Text {
                    text: root.waiting ? root.waitingFor
                        : root.busy ? (root.toolName !== "" ? root.toolName : "thinking")
                        : "idle"
                    color: root.waiting ? Colors.claudeAttention : Colors.claudeTitle
                    font.family: "caelusevka"
                    font.pixelSize: 14
                }

                // Kept in the layout even when it is empty, so the line does
                // not reflow the instant a tool call finishes.
                Text {
                    Layout.fillWidth: true
                    text: root.busy ? root.toolTarget : ""
                    color: Colors.claudeMeta
                    font.family: "caelusevka"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 4

                Repeater {
                    model: root.chips

                    Rectangle {
                        id: chip

                        required property var modelData

                        implicitWidth: chipText.implicitWidth + 14
                        implicitHeight: 20
                        radius: 4
                        color: Colors.claudePanelBg

                        Text {
                            id: chipText

                            anchors.centerIn: parent
                            text: chip.modelData.text
                            color: chip.modelData.accent ? Colors.claudeAccent : Colors.claudeMeta
                            font.family: "caelusevka"
                            font.pixelSize: 12
                        }
                    }
                }
            }

            ClaudeStatRow {
                Layout.topMargin: 2
                label: "context"
                value: ClaudeSession.compact(root.ctxTokens) + " / " + ClaudeSession.compact(root.ctxLimit)
                valueColor: ClaudeSession.levelColor(root.ctxPct)
            }

            ClaudeMeter {
                Layout.fillWidth: true
                fraction: root.ctxPct / 100
                percent: root.ctxPct
            }

            ClaudeStatRow {
                Layout.topMargin: 2
                label: "plan · " + root.planName
                value: root.planDone + " / " + root.planTotal
                visible: root.planName !== ""
            }

            ClaudeMeter {
                Layout.fillWidth: true
                fraction: root.planTotal > 0 ? root.planDone / root.planTotal : 0
                percent: -1
                fill: Colors.claudeAccent
                visible: root.planName !== ""
            }
        }

        // ── subagents ────────────────────────────────────────────────────
        // The section this whole panel exists for: several agents at once is
        // the normal case here, and nothing anywhere else on the bar says so.
        ClaudeSection {
            Layout.fillWidth: true
            title: "Subagents"
            trailing: root.subagentSummary
            visible: root.subs.length > 0

            Repeater {
                model: root.subs

                Rectangle {
                    id: agent

                    required property var modelData
                    readonly property var a: agent.modelData

                    Layout.fillWidth: true
                    // Nesting is drawn rather than written: an agent spawned by
                    // another agent is a different thing to reason about than
                    // one you started yourself.
                    Layout.leftMargin: Math.max(0, (agent.a.spawnDepth ?? 1) - 1) * 12
                    implicitHeight: agentCol.implicitHeight + 12
                    radius: 8
                    color: Colors.claudePanelBg

                    ColumnLayout {
                        id: agentCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: agent.a.running ? "radio_button_checked" : "check_circle"
                                color: agent.a.running ? Colors.claudeAgent : Colors.claudeIdle
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 13
                            }

                            Text {
                                text: agent.a.agentType
                                color: agent.a.running ? Colors.claudeAgent : Colors.claudeBody
                                font.family: "caelusevka"
                                font.pixelSize: 13
                            }

                            Text {
                                Layout.fillWidth: true
                                text: agent.a.description
                                color: Colors.claudeMeta
                                font.family: "caelusevka"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            // A running agent wants a stopwatch; a finished one
                            // wants to say how stale its result already is.
                            Text {
                                text: agent.a.running
                                    ? ClaudeSession.elapsed(Date.parse(agent.a.startedAt))
                                    : ClaudeSession.ago(agent.a.lastAt)
                                color: agent.a.running ? Colors.claudeAgent : Colors.claudeMeta
                                font.family: "caelusevka"
                                font.pixelSize: 12
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                const bits = [];
                                if ((agent.a.model ?? "") !== "") bits.push(agent.a.model);
                                if (root.num(agent.a, "tools") > 0) bits.push(agent.a.tools + " tools");
                                if (root.num(agent.a, "outputTokens") > 0)
                                    bits.push(ClaudeSession.compact(agent.a.outputTokens) + " out");
                                if (root.num(agent.a, "cost") > 0) bits.push(root.money(agent.a.cost));
                                return bits.join("  ·  ");
                            }
                            color: Colors.claudeMeta
                            font.family: "caelusevka"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }
                }
            }
        }

        // ── activity ─────────────────────────────────────────────────────
        ClaudeSection {
            Layout.fillWidth: true
            title: "Activity"
            // A transcript only flushes once a tool has returned, so the newest
            // entry here lags the row's own live column by one call.
            trailing: root.acts.length > 0 ? ClaudeSession.ago(root.acts[0].at) : ""
            visible: root.acts.length > 0

            ClaudeActivityFeed {
                Layout.fillWidth: true
                entries: root.acts
            }
        }

        // ── prompt & queue ───────────────────────────────────────────────
        ClaudeSection {
            Layout.fillWidth: true
            title: "Prompt"
            trailing: root.queue.length > 0 ? root.queue.length + " queued" : ""
            visible: root.promptText !== "" || root.queue.length > 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.promptText !== ""

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 2
                    radius: 1
                    color: Colors.claudeDim
                }

                Text {
                    Layout.fillWidth: true
                    text: root.promptText
                    color: Colors.claudeBody
                    font.family: "caelusevka"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            Repeater {
                model: root.queue

                RowLayout {
                    id: queued

                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: (queued.index + 1) + "."
                        color: Colors.claudeAccent
                        font.family: "caelusevka"
                        font.pixelSize: 13
                    }

                    Text {
                        Layout.fillWidth: true
                        text: queued.modelData.content
                        color: Colors.claudeMeta
                        font.family: "caelusevka"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Text {
                        text: ClaudeSession.ago(queued.modelData.at)
                        color: Colors.claudeMeta
                        font.family: "caelusevka"
                        font.pixelSize: 12
                    }
                }
            }
        }

        // ── economics ────────────────────────────────────────────────────
        ClaudeSection {
            Layout.fillWidth: true
            title: "Economics"
            trailing: root.num(root.econ, "turns") + " turns"
            visible: root.econ !== null

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.money(root.num(root.econ, "cost") + root.num(root.econ, "subagentCost"))
                    color: Colors.claudeAccent
                    font.family: "caelusevka"
                    font.pixelSize: 20
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 2
                    text: root.num(root.econ, "subagentCost") > 0
                        ? "incl. " + root.money(root.econ.subagentCost) + " agents"
                        : "this session"
                    color: Colors.claudeMeta
                    font.family: "caelusevka"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 2
                    text: root.growthText
                    color: root.growthColor
                    font.family: "caelusevka"
                    font.pixelSize: 12
                    visible: text !== ""
                }
            }

            // Two columns rather than six stacked rows: the figures are all
            // short, and a section this tall would otherwise push the sections
            // below it clean off the panel.
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                columns: 2
                columnSpacing: 16
                rowSpacing: 1

                ClaudeStatRow {
                    label: "input"
                    value: ClaudeSession.compact(root.num(root.econ, "input"))
                }

                ClaudeStatRow {
                    label: "output"
                    value: ClaudeSession.compact(root.num(root.econ, "output"))
                }

                ClaudeStatRow {
                    label: "thinking"
                    value: ClaudeSession.compact(root.num(root.econ, "thinking"))
                }

                ClaudeStatRow {
                    label: "tools"
                    value: String(root.num(root.econ, "tools"))
                }

                ClaudeStatRow {
                    label: "cache read"
                    value: ClaudeSession.compact(root.num(root.econ, "cacheRead"))
                    dim: true
                }

                // The two write TTLs are priced apart upstream but read as one
                // number here; the split matters to the cost, not to the eye.
                ClaudeStatRow {
                    label: "cache write"
                    value: ClaudeSession.compact(root.num(root.econ, "cacheWrite1h")
                        + root.num(root.econ, "cacheWrite5m"))
                    dim: true
                }
            }
        }

        // ── files & git ──────────────────────────────────────────────────
        ClaudeSection {
            Layout.fillWidth: true
            title: "Files"
            trailing: root.files.length > 0 ? root.files.length + " edited" : ""
            visible: root.files.length > 0 || (root.git !== null && root.git.repo === true)

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.git !== null && root.git.repo === true

                Text {
                    text: "call_split"
                    color: Colors.claudeMeta
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 14
                }

                Text {
                    text: root.git ? root.git.branch : ""
                    color: Colors.claudeBody
                    font.family: "caelusevka"
                    font.pixelSize: 13
                }

                Text {
                    text: root.num(root.git, "dirty") + " dirty"
                    color: root.num(root.git, "dirty") > 0 ? Colors.claudeWarn : Colors.claudeMeta
                    font.family: "caelusevka"
                    font.pixelSize: 13
                }

                Text {
                    Layout.fillWidth: true
                    text: "↑" + root.num(root.git, "ahead") + "  ↓" + root.num(root.git, "behind")
                    color: Colors.claudeMeta
                    font.family: "caelusevka"
                    font.pixelSize: 13
                }
            }

            Repeater {
                model: root.files

                RowLayout {
                    id: edited

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root.relative(edited.modelData.path)
                        color: Colors.claudeBody
                        font.family: "caelusevka"
                        font.pixelSize: 12
                        // ElideLeft: the directory is the disposable half of a
                        // path, the filename is the whole point of the line.
                        elide: Text.ElideLeft
                    }

                    Text {
                        text: "×" + edited.modelData.edits
                        color: Colors.claudeMeta
                        font.family: "caelusevka"
                        font.pixelSize: 12
                    }
                }
            }
        }

        // ── footer ───────────────────────────────────────────────────────
        ClaudeSection {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: root.cwd
                color: cwdArea.containsMouse ? Colors.claudeAccent : Colors.claudeMeta
                font.family: "caelusevka"
                font.pixelSize: 12
                elide: Text.ElideMiddle

                MouseArea {
                    id: cwdArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.clipboardText = root.cwd
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.sessionId
                color: idArea.containsMouse ? Colors.claudeAccent : Colors.claudeMeta
                font.family: "caelusevka"
                font.pixelSize: 12
                elide: Text.ElideMiddle

                MouseArea {
                    id: idArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.clipboardText = root.sessionId
                }
            }
        }
    }
}
