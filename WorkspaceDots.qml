import QtQuick
import Quickshell.Hyprland
import qs.Config
import qs.Services

Row {
    id: root

    required property HyprlandMonitor monitor

    spacing: 6
    // Fixed, and the dots hang off its centre. The active dot turns into a
    // tall capsule when it is carrying a count, and a Row sized by its
    // children would otherwise move the whole thing up and down inside the
    // bar as windows come and go behind a fullscreen one.
    height: 20

    Repeater {
        model: Workspaces.dotsFor(root.monitor)

        Item {
            id: slot

            required property HyprlandWorkspace modelData
            readonly property bool active: slot.modelData.id === root.monitor?.activeWorkspace?.id
            readonly property bool occupied: Workspaces.windowCount(slot.modelData.id) > 0

            // Only ever on the dot you are looking at. A count on an inactive
            // workspace would be describing somewhere you are not, and the
            // thing being reported -- that what is in front of you is hiding
            // the rest -- is only true of the one you are on.
            readonly property int hidden: slot.active ? Workspaces.focusedHidden : 0
            readonly property bool badge: slot.hidden > 0

            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: slot.badge ? 20 : 8
            implicitWidth: slot.badge ? label.implicitWidth + 20 : slot.active ? 20 : 8

            Behavior on implicitWidth { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

            Rectangle {
                id: body

                anchors.fill: parent
                radius: height / 2
                color: slot.active ? Colors.dotActive : slot.occupied ? Colors.dotOccupied : Colors.dotEmpty

                Behavior on color { ColorAnimation { duration: 150 } }

                // A glyph and the number, not the number alone. One digit
                // inside a dot was clean and said nothing at a glance: it
                // reads as decoration until you already know to look for it.
                // Stacked sheets plus a count is the one arrangement that
                // cannot be read as anything except "there are more of these
                // behind this".
                Row {
                    id: label

                    anchors.centerIn: parent
                    spacing: 3
                    opacity: slot.badge ? 1 : 0
                    visible: slot.implicitHeight > 10

                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "layers"
                        color: Caelus.textOnAccent
                        font.family: Caelus.symbolFamily
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: slot.hidden
                        color: Caelus.textOnAccent
                        font.family: Caelus.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                // Clicking the workspace you are already on does nothing, so
                // while it is carrying a count that click is free: it drops
                // the covering window back into the stack and the others come
                // back. Everywhere else it still just switches workspace.
                onClicked: {
                    if (slot.badge) Workspaces.uncover();
                    else Workspaces.switchTo(slot.modelData.id);
                }
            }
        }
    }
}
