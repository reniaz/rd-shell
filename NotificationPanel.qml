import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The notification centre, hung under the bar's bell. The card, its notch, the
// grow-out-of-the-icon animation and the click-outside dismissal all belong to
// BarPopup; what is left here is the history itself.
BarPopup {
    id: root

    namespace: "qs-notifications"
    popupWidth: 400

    // As short as the history is, up to everything between the notch and the
    // bottom of the screen. 36 is the card's own margins and 12 the gap under
    // the header; an empty centre is the header and nothing else.
    popupHeight: Math.min(root.height - 60,
        36 + head.implicitHeight + (Notifications.count > 0 ? 12 + groups.contentHeight : 0))

    // The service holds the open state rather than the loader, because Escape,
    // the bell and the IPC handler can all shut this panel and only one of them
    // is this window.
    open: Notifications.panelOpen

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        // The header, measured on its own: a card that sized itself from the
        // same layout it stretches would be feeding its own height back into
        // the sum, and settles at zero when it does.
        ColumnLayout {
            id: head

            Layout.fillWidth: true
            // The list below is the only thing that gives when the screen is
            // shorter than the panel wants to be.
            Layout.minimumHeight: implicitHeight
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Notifications.dnd ? "notifications_off" : "notifications"
                    color: Notifications.dnd ? Colors.notifDndOn : Colors.notifDndOff
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.toggleDnd()
                    }
                }

                Text {
                    text: "Notifications"
                    color: Colors.notifTitle
                    font.family: "caelusevka"
                    font.pixelSize: 16
                    Layout.fillWidth: true
                }

                Text {
                    text: Notifications.count
                    color: Colors.notifMeta
                    font.family: "caelusevka"
                    font.pixelSize: 14
                }

                Text {
                    text: "clear_all"
                    color: clearArea.containsMouse ? Colors.notifCritical : Colors.notifMeta
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    visible: Notifications.count > 0

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.dismissAll()
                    }
                }
            }

            Text {
                text: "Nothing here"
                color: Colors.notifMeta
                font.family: "caelusevka"
                font.pixelSize: 14
                visible: Notifications.count === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 20
            }

        }
        ListView {
            id: groups

            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 18
            clip: true
            // Every card exists whatever height the view is given, so
            // contentHeight is a property of the history and not of the panel
            // wrapped around it -- which is what lets the panel size itself
            // from it.
            cacheBuffer: 100000
            model: Notifications.grouped

            delegate: Column {
                id: section

                required property var modelData
                readonly property var group: modelData

                width: groups.width
                spacing: 8

                Row {
                    spacing: 6

                    Text {
                        text: section.group.app
                        color: Colors.notifSection
                        font.family: "caelusevka"
                        font.pixelSize: 13
                    }

                    Text {
                        text: section.group.items.length
                        color: Colors.notifMeta
                        font.family: "caelusevka"
                        font.pixelSize: 13
                    }
                }

                Repeater {
                    model: section.group.items

                    NotificationCard {
                        required property var modelData

                        width: section.width
                        notification: modelData
                        showApp: false
                    }
                }
            }
        }
    }
}
