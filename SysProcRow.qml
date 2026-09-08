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

    required property var proc
    property string value

    // The row under the pointer when the confirmation opened is not necessarily
    // the row still there when it is answered, so the pid is pinned at the
    // moment of asking and the question withdrawn if the row changes under it.
    property bool confirming: false
    readonly property int pid: root.proc?.pid ?? 0

    onPidChanged: root.confirming = false

    Layout.fillWidth: true
    implicitHeight: 27
    radius: 8
    color: hover.hovered || root.confirming ? Colors.sysTrack : "transparent"

    Behavior on color { ColorAnimation { duration: 120 } }

    HoverHandler { id: hover }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 5
        spacing: 7

        Text {
            text: root.proc?.name ?? ""
            color: Colors.sysTitle
            font.family: "caelusevka"
            font.pixelSize: 13
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            text: root.pid
            color: Colors.sysMeta
            font.family: "caelusevka"
            font.pixelSize: 11
            visible: !root.confirming
        }

        Text {
            text: root.value
            color: Colors.sysBody
            font.family: "caelusevka"
            font.pixelSize: 13
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

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: caption

                    anchors.centerIn: parent
                    text: button.modelData.label
                    color: buttonHover.hovered ? Colors.bg : Colors.sysKill
                    font.family: "caelusevka"
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
            font.family: "Material Symbols Rounded"
            font.pixelSize: 15
            // Kept in the layout while hidden so the value column does not
            // shuffle sideways as the pointer crosses the list.
            opacity: hover.hovered || root.confirming ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 120 } }

            HoverHandler { id: killHover; cursorShape: Qt.PointingHandCursor }

            TapHandler {
                enabled: hover.hovered || root.confirming
                onTapped: root.confirming = !root.confirming
            }
        }
    }
}
