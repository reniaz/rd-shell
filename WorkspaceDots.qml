import QtQuick
import Quickshell.Hyprland
import qs.Config
import qs.Services

Row {
    id: root

    required property HyprlandMonitor monitor

    spacing: 6

    Repeater {
        model: Workspaces.dotsFor(root.monitor)

        Rectangle {
            required property HyprlandWorkspace modelData
            readonly property bool active: modelData.id === root.monitor?.activeWorkspace?.id
            readonly property bool occupied: Workspaces.windowCount(modelData.id) > 0

            height: 8
            width: active ? 20 : 8
            radius: height / 2
            color: active ? Colors.dotActive : occupied ? Colors.dotOccupied : Colors.dotEmpty

            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: Workspaces.switchTo(modelData.id)
            }
        }
    }
}
