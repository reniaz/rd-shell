import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// A short peek at the notification history, reusing NotificationCard.qml --
// the same delegate NotificationPanel.qml's own list draws -- rather than a
// second card layout. Capped to the newest few (`maxShown`): the dashboard
// is a glance, and the full history with its DND toggle and clear-all
// already has a home in the bell's own panel.
ColumnLayout {
    id: root

    readonly property int maxShown: 3

    spacing: Caelus.space

    RowLayout {
        Layout.fillWidth: true
        spacing: Caelus.space

        Text {
            text: "notifications"
            color: Colors.notifIcon
            font.family: Caelus.symbolFamily
            font.pixelSize: Caelus.sizeLead
        }

        Text {
            Layout.fillWidth: true
            text: "Notifications"
            color: Colors.notifTitle
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeBody
        }

        Text {
            text: Notifications.count
            color: Colors.notifMeta
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: Caelus.spaceTight
        text: "Nothing here"
        color: Colors.notifMeta
        font.family: Caelus.fontFamily
        font.pixelSize: Caelus.sizeLabel
        visible: Notifications.count === 0
        horizontalAlignment: Text.AlignHCenter
    }

    Repeater {
        model: Notifications.list.slice(0, root.maxShown)

        NotificationCard {
            required property var modelData

            // No `onActivated` handler, matching NotificationPanel.qml's own
            // list exactly: the card already invokes its default action (and
            // dismisses itself for a resident notification) on a body click
            // with no help from the caller -- see NotificationCard.qml's own
            // MouseArea.
            Layout.fillWidth: true
            notification: modelData
            showApp: true
        }
    }
}
