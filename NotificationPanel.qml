import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The notification centre, hung under the bar's bell. The card, the
// grow-out-of-the-icon animation and the click-outside dismissal all belong to
// BarPopup; what is left here is the history itself.
BarPopup {
    id: root

    namespace: "qs-notifications"
    popupWidth: 400

    // As short as the history is, up to everything between the card and the
    // bottom of the screen. 36 is the card's own margins and 12 the gap under
    // the header; an empty centre is the header and nothing else.
    //
    // The screen cap only applies once there is a screen height to cap against.
    // A layer surface is told its size a round trip after it is created, so for
    // the first frames `root.height` is zero, and an unguarded Math.min against
    // it asks for a card fifty-two pixels tall -- which is how the panel came to
    // open at BarPopup's floor and then unfold into itself.
    popupHeight: root.height > 0
        ? Math.min(root.height - (Caelus.barHeight - Caelus.barInset + Caelus.spaceEdge), root.wantedHeight)
        : root.wantedHeight

    readonly property real wantedHeight: 36 + head.implicitHeight
        + (Notifications.count > 0 ? 12 + groups.contentHeight : 0)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: Caelus.spaceWide

        // The header, measured on its own: a card that sized itself from the
        // same layout it stretches would be feeding its own height back into
        // the sum, and settles at zero when it does.
        ColumnLayout {
            id: head

            Layout.fillWidth: true
            // The list below is the only thing that gives when the screen is
            // shorter than the panel wants to be.
            Layout.minimumHeight: implicitHeight
            spacing: Caelus.spaceWide

            RowLayout {
                Layout.fillWidth: true
                spacing: Caelus.space

                Text {
                    text: Notifications.dnd ? "notifications_off" : "notifications"
                    color: Notifications.dnd ? Colors.notifDndOn : Colors.notifDndOff
                    font.family: Caelus.symbolFamily
                    font.pixelSize: Caelus.sizeTitle

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
                    font.family: Caelus.fontFamily
                    font.pixelSize: 16
                    Layout.fillWidth: true
                }

                Text {
                    text: Notifications.count
                    color: Colors.notifMeta
                    font.family: Caelus.fontFamily
                    font.pixelSize: 14
                }

                Text {
                    text: "clear_all"
                    color: clearArea.containsMouse ? Colors.notifCritical : Colors.notifMeta
                    font.family: Caelus.symbolFamily
                    font.pixelSize: Caelus.sizeTitle
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
                font.family: Caelus.fontFamily
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
                spacing: Caelus.space

                Row {
                    spacing: Caelus.spaceSnug

                    Text {
                        text: section.group.app
                        color: Colors.notifSection
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeBody
                    }

                    Text {
                        text: section.group.items.length
                        color: Colors.notifMeta
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeBody
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
