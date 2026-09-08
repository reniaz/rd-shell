import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// One switch on the Optimize tab. A card of its own rather than a ClaudeStatRow,
// because what decides whether to press the button is the detail underneath it:
// an "Apply" beside a bare title is a dare, not an offer.
Rectangle {
    id: root

    required property var rule

    // Pulled out of the object once each. The status payload is replaced
    // wholesale on every apply, and a row that reached through `rule` at four
    // different points could be half-bound to the old one and half to the new.
    readonly property bool applied: root.rule?.applied ?? false
    readonly property string risk: root.rule?.risk ?? ""

    // fillWidth here and not at the call site, for the same reason ClaudeStatRow
    // does it: a rule that does not span its section is never what anyone wants.
    Layout.fillWidth: true

    implicitHeight: inner.implicitHeight + 20
    radius: 10

    // An applied rule is tinted and striped rather than only re-labelled. There
    // are thirteen of these and "how many are on" has to be answerable by
    // looking at the list, not by reading thirteen buttons.
    color: root.applied
        ? Qt.rgba(Colors.claudeAccent.r, Colors.claudeAccent.g,
                  Colors.claudeAccent.b, 0.10)
        : "transparent"

    Behavior on color { ColorAnimation { duration: 160 } }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 4
        width: 2
        radius: width / 2
        color: Colors.claudeAccent
        visible: root.applied
    }

    ColumnLayout {
        id: inner

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: root.rule?.title ?? ""
                color: Colors.claudeTitle
                font.family: "caelusevka"
                font.pixelSize: 13
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // One word, and always the same five words across the list, so the
            // rules can be scanned for the axis you are actually short of
            // rather than read end to end.
            Rectangle {
                implicitWidth: savesLabel.implicitWidth + 12
                implicitHeight: savesLabel.implicitHeight + 4
                radius: height / 2
                color: Colors.claudeTrack
                visible: savesLabel.text !== ""

                Text {
                    id: savesLabel

                    anchors.centerIn: parent
                    text: root.rule?.saves ?? ""
                    color: Colors.claudeMeta
                    font.family: "caelusevka"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                id: action

                // Every button in the tab goes dead together while a write is in
                // flight: the script rewrites the whole of settings.json, so a
                // second apply landing on top of the first would be racing it
                // for the file.
                readonly property bool live: !ClaudeOptimize.busy

                implicitWidth: actionLabel.implicitWidth + 20
                implicitHeight: 24
                radius: height / 2
                color: actionArea.containsMouse && action.live
                    ? Colors.claudeTrack
                    : "transparent"
                border.width: 1
                border.color: Colors.claudeBorder
                opacity: action.live ? 1 : 0.4

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Text {
                    id: actionLabel

                    anchors.centerIn: parent
                    text: root.applied ? "Remove" : "Apply"
                    // Removing is the destructive half and only turns red under
                    // the cursor, so the resting list reads as a set of offers
                    // with no warnings in it.
                    color: root.applied
                        ? (actionArea.containsMouse ? Colors.claudeCritical : Colors.claudeMeta)
                        : Colors.claudeAccent
                    font.family: "caelusevka"
                    font.pixelSize: 12

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    id: actionArea

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: action.live
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const id = root.rule?.id ?? "";
                        if (id === "") return;
                        if (root.applied) ClaudeOptimize.revert(id);
                        else ClaudeOptimize.apply(id);
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.rule?.detail ?? ""
            color: Colors.claudeBody
            font.family: "caelusevka"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        // Only the settings rules print what they write. There the value is one
        // short `KEY=value` and seeing it is the difference between trusting the
        // panel and trusting the title; a CLAUDE.md rule's text is already the
        // detail above it, so repeating it would say the same thing twice.
        Text {
            Layout.fillWidth: true
            text: (root.rule?.target ?? "") + " · " + (root.rule?.value ?? "")
            visible: (root.rule?.section ?? "") === "settings"
            color: Colors.claudeMeta
            font.family: "caelusevka"
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        // In warn and not in critical: nothing here breaks anything, and a red
        // line on nine of thirteen rows would make the colour mean "row" rather
        // than "read this before pressing".
        Text {
            Layout.fillWidth: true
            text: root.risk
            visible: root.risk !== ""
            color: Colors.claudeWarn
            font.family: "caelusevka"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }
}
