import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The one tab that changes something rather than reporting it: a list of
// settings and standing instructions that make a turn cost less, each with the
// switch that applies it. It opens on the account's own token split because
// every rule below is an argument about one of those four bars -- an optimiser
// that cannot show you what it is optimising is a list of superstitions.
Flickable {
    id: root

    readonly property var totals: ClaudeGlobal.totals

    // Four bars against one denominator, so they are readable as parts of the
    // same whole. Every field here is one the lifetime scan actually emits;
    // nothing in this tab is estimated, assumed or scaled.
    readonly property var split: {
        const t = ClaudeGlobal.totals;
        if (t === null || t === undefined) return [];

        const all = (t.tokens ?? 0) > 0 ? t.tokens : 1;
        const row = (label, value, note) => ({
            label: label,
            value: ClaudeSession.compact(value ?? 0),
            fraction: (value ?? 0) / all,
            sublabel: note
        });

        return [
            row("cache read", t.cacheRead,
                "the conversation so far, re-sent every turn at a tenth of input"),
            row("cache write", t.cacheWrite,
                "what a changed prefix costs to lay down again"),
            row("input", t.input,
                "fresh context: files read, tool output, your prompts"),
            row("output", t.output,
                "everything written back, thinking counted inside it")
        ];
    }

    // The share the reading line leans on, rounded once here so the sentence and
    // the bar above it cannot disagree by a percent.
    readonly property int cacheShare: {
        const t = ClaudeGlobal.totals;
        if (t === null || t === undefined) return 0;
        if ((t.tokens ?? 0) <= 0) return 0;
        return Math.round(((t.cacheRead ?? 0) / t.tokens) * 100);
    }

    // Split on `section` rather than drawn as one list: the two halves are
    // written to different files by different means, and reverting one is a jq
    // delete while reverting the other is a block of your own CLAUDE.md coming
    // back out. That is worth a heading each.
    readonly property var settingsRules: ClaudeOptimize.rules.filter(r => r.section === "settings")
    readonly property var textRules: ClaudeOptimize.rules.filter(r => r.section === "rules")

    // `applied` is read off disk on every status call, so the tab has to ask
    // once on open -- the file may well have been edited by hand since the last
    // time this window existed.
    Component.onCompleted: ClaudeOptimize.refresh()

    // The service drops `password` the instant it has fed sudo's stdin, which
    // would leave the second Apply of a session with nothing to send. This field
    // is the only copy that outlives the call, so it puts the value back rather
    // than making you retype it per rule -- and it goes when elevation stops
    // being needed, which is the moment the value stops having a use.
    Connections {
        target: ClaudeOptimize

        function onPasswordChanged() {
            if (ClaudeOptimize.password === "" && pw.text !== "")
                ClaudeOptimize.password = pw.text;
        }

        function onNeedsSudoChanged() {
            if (!ClaudeOptimize.needsSudo) pw.text = "";
        }
    }

    clip: true
    contentWidth: width
    contentHeight: optimizeCol.implicitHeight
    readonly property real naturalHeight: root.contentHeight
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: optimizeCol

        width: root.width
        spacing: 12

        // Only shown while the password field is not on screen. When it is, the
        // error is almost always about that field and belongs beside it -- the
        // same sentence printed twice on one screen reads as two failures.
        Text {
            Layout.fillWidth: true
            text: ClaudeOptimize.error
            visible: ClaudeOptimize.error !== "" && !ClaudeOptimize.needsSudo
            color: Colors.claudeCritical
            font.family: "caelusevka"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        ClaudeSection {
            Layout.fillWidth: true
            title: "where your tokens go"
            trailing: ClaudeGlobal.ready
                ? ClaudeSession.compact(root.totals?.tokens ?? 0) + " lifetime"
                : ""
            visible: root.split.length > 0

            Repeater {
                model: root.split

                ClaudeRankRow {
                    id: splitRow

                    required property var modelData

                    Layout.fillWidth: true
                    label: splitRow.modelData.label
                    value: splitRow.modelData.value
                    fraction: splitRow.modelData.fraction
                    sublabel: splitRow.modelData.sublabel
                }
            }

            // The reading, and the reason the list below is shaped the way it
            // is: none of these rules makes a token cheaper, they all make the
            // thing being re-sent smaller or re-send it less often.
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: root.cacheShare + "% of every token this account has moved was a cache "
                    + "read — the same conversation, paid for again on each turn. Nothing "
                    + "below makes a token cheaper; they shorten what gets re-sent, or cut "
                    + "how many turns re-send it."
                color: Colors.claudeMeta
                font.family: "caelusevka"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        // Above the list rather than beside the rule it argues for: this is the
        // one figure that says whether routing subagents to a cheaper model is
        // worth anything on this account, and it is measured, not assumed.
        Text {
            Layout.fillWidth: true
            text: ClaudeSession.money(root.totals?.subagentCost ?? 0) + " of "
                + ClaudeSession.money(root.totals?.cost ?? 0) + " went to subagents"
            visible: (root.totals?.subagentCost ?? 0) > 0
            color: Colors.claudeBody
            font.family: "caelusevka"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: ClaudeOptimize.ready
                    ? ClaudeOptimize.appliedCount + " of " + ClaudeOptimize.totalCount + " applied"
                    : "reading ~/.claude…"
                color: Colors.claudeMeta
                font.family: "caelusevka"
                font.pixelSize: 13
                Layout.fillWidth: true
            }

            Rectangle {
                id: applyAll

                // Nothing left to do is a different state from a write in
                // flight, but both mean the button must not be pressed, so they
                // share one condition and one dimming.
                readonly property bool live: ClaudeOptimize.ready
                    && !ClaudeOptimize.busy
                    && ClaudeOptimize.appliedCount < ClaudeOptimize.totalCount

                implicitWidth: applyAllLabel.implicitWidth + 22
                implicitHeight: 26
                radius: height / 2
                color: applyAllArea.containsMouse && applyAll.live
                    ? Colors.claudeTrack
                    : "transparent"
                border.width: 1
                border.color: Colors.claudeBorder
                opacity: applyAll.live ? 1 : 0.4

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Text {
                    id: applyAllLabel

                    anchors.centerIn: parent
                    text: ClaudeOptimize.busy ? "working…" : "Apply all"
                    color: Colors.claudeAccent
                    font.family: "caelusevka"
                    font.pixelSize: 12
                }

                MouseArea {
                    id: applyAllArea

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: applyAll.live
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ClaudeOptimize.applyAll()
                }
            }
        }

        // Only ever on screen when the script has reported that it cannot write
        // the files itself. When ~/.claude belongs to the user -- which is the
        // normal case -- there is no field, no prompt and no sudo anywhere in
        // this tab.
        ClaudeSection {
            Layout.fillWidth: true
            visible: ClaudeOptimize.needsSudo

            Text {
                Layout.fillWidth: true
                text: "~/.claude is not writable by you — sudo password needed to change these"
                color: Colors.claudeWarn
                font.family: "caelusevka"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 8
                color: Colors.claudeTabBar
                border.width: 1
                border.color: pw.activeFocus ? Colors.claudeAccent : Colors.claudeBorder

                Behavior on border.color { ColorAnimation { duration: 120 } }

                TextInput {
                    id: pw

                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    // The password exists in exactly two places: this field and
                    // the service's transient copy. It is never a command
                    // argument, never a log line and never drawn as text.
                    echoMode: TextInput.Password
                    color: Colors.claudeTitle
                    font.family: "caelusevka"
                    font.pixelSize: 13
                    selectByMouse: true
                    onTextChanged: ClaudeOptimize.password = pw.text
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "sudo password"
                    visible: pw.text === ""
                    color: Colors.claudeMeta
                    font.family: "caelusevka"
                    font.pixelSize: 13
                }
            }

            Text {
                Layout.fillWidth: true
                text: ClaudeOptimize.error
                visible: ClaudeOptimize.error !== ""
                color: Colors.claudeCritical
                font.family: "caelusevka"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        ClaudeSection {
            Layout.fillWidth: true
            title: "settings.json"
            visible: root.settingsRules.length > 0

            Repeater {
                model: root.settingsRules

                ClaudeRuleRow {
                    id: settingRow

                    required property var modelData

                    rule: settingRow.modelData
                }
            }
        }

        ClaudeSection {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            title: "global rules"
            visible: root.textRules.length > 0

            Repeater {
                model: root.textRules

                ClaudeRuleRow {
                    id: textRow

                    required property var modelData

                    rule: textRow.modelData
                }
            }
        }

        // Where the rules half actually lands, said once at the foot rather than
        // on each of the five rows that do it. A user who finds an unfamiliar
        // section in their own CLAUDE.md should be able to trace it back here.
        Text {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            text: "The rules above are written into ~/.claude/CLAUDE.md inside one marked "
                + "section, and removing the last of them takes the section with it."
            visible: root.textRules.length > 0
            color: Colors.claudeMeta
            font.family: "caelusevka"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }
}
