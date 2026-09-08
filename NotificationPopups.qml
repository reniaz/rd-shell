import Quickshell
import Quickshell.Wayland
import QtQuick
import Quickshell.Services.Notifications
import qs.Config
import qs.Services

PanelWindow {
    id: root

    // floats clear of the screen edge -- 54 clears the 40px bar plus the bar's
    // own 14px edge rhythm
    anchors { top: true; right: true }
    margins { top: 54; right: 14 }
    implicitWidth: 400
    implicitHeight: Math.max(1, column.implicitHeight)

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-popups"
    color: "transparent"

    Column {
        id: column

        width: parent.width
        spacing: 10

        Repeater {
            model: Notifications.popups

            NotificationCard {
                required property var modelData
                property bool entered: false

                width: column.width
                notification: modelData
                popup: true

                x: entered ? 0 : width
                Component.onCompleted: entered = true

                Behavior on x {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                // Lifetime is Notifications.popupTimer's job now, so the stack
                // clears in one go instead of dribbling away card by card.
                // The card owns the click; only retiring the toast is ours.
                onActivated: Notifications.hidePopup(modelData)
            }
        }
    }
}
