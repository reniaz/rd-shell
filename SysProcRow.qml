import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// One process, and the two ways of ending it.
//
// The kill affordance only appears under the pointer and asks a second time
// before it fires: the list re-sorts itself every few seconds, and a single
// click on a moving row is not consent to end a program.
Rectangle {
    id: root

    // One required property per role rather than the whole row object, the same
    // way ClaudeSessionRow reads the other reconciled model in this shell: the
    // delegate machinery fills a required property from the role of the same
    // name, so a process whose figure moved updates that one property instead of
    // arriving as a replacement row.
    required property int pid
    required property string name

    property string value

    // The row under the pointer when the confirmation opened is not necessarily
    // the row still there when it is answered, so the question is withdrawn if
    // the row changes under it. SysMon's reconciler moves a row rather than
    // overwriting it, so a pid should never change under a delegate at all --
    // this is what makes that a guarantee rather than a hope.
    property bool confirming: false

    onPidChanged: root.confirming = false

    Layout.fillWidth: true
    implicitHeight: 27
    radius: Caelus.radiusCard
    color: hover.hovered || root.confirming ? Colors.sysTrack : "transparent"

    Behavior on color { ColorAnimation { duration: Motion.fast } }

    HoverHandler { id: hover }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 5
        spacing: 7

        Text {
            text: root.name
            color: Colors.sysTitle
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeBody
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            text: root.pid
            color: Colors.sysMeta
            font.family: Caelus.fontFamily
            font.pixelSize: 11
            visible: !root.confirming
        }

        Text {
            text: root.value
            color: Colors.sysBody
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeBody
            // A fixed column: the pid beside it is four to seven digits wide,
            // and without this the readings zig-zag down the list.
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: 46
            visible: !root.confirming
        }

        // Asked once, then answered: the two signals are separate buttons
        // because they are separate promises, and neither is the default.
        Repeater {
            model: root.confirming
                ? [{ label: "End", force: false }, { label: "Force", force: true }]
                : []

            Rectangle {
                id: button

                required property var modelData

                implicitWidth: caption.implicitWidth + 14
                implicitHeight: 19
                radius: 9
                color: buttonHover.hovered ? Colors.sysKill : "transparent"
                border.width: 1
                border.color: Colors.sysKill

                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Text {
                    id: caption

                    anchors.centerIn: parent
                    text: button.modelData.label
                    color: buttonHover.hovered ? Colors.bg : Colors.sysKill
                    font.family: Caelus.fontFamily
                    font.pixelSize: 11
                }

                HoverHandler { id: buttonHover; cursorShape: Qt.PointingHandCursor }

                TapHandler {
                    onTapped: {
                        SysMon.kill(root.pid, button.modelData.force);
                        root.confirming = false;
                    }
                }
            }
        }

        Text {
            text: root.confirming ? "close" : "cancel"
            color: killHover.hovered ? Colors.sysKill : Colors.sysMeta
            font.family: Caelus.symbolFamily
            font.pixelSize: Caelus.sizeLead
            // Kept in the layout while hidden so the value column does not
            // shuffle sideways as the pointer crosses the list.
            opacity: hover.hovered || root.confirming ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

            HoverHandler { id: killHover; cursorShape: Qt.PointingHandCursor }

            TapHandler {
                enabled: hover.hovered || root.confirming
                onTapped: root.confirming = !root.confirming
            }
        }
    }
}
