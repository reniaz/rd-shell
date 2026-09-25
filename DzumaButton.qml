import QtQuick
import qs.Config

// The two actions under a drop. Small enough that a shared button would cost
// more than it saves, local enough that it stays beside the popup that uses it.
Rectangle {
    id: root

    property string label: ""
    property bool accent: false

    signal triggered()

    implicitHeight: 28
    radius: 6
    color: area.containsMouse ? Colors.popupAccent : Colors.popupBorder

    Text {
        anchors.centerIn: parent
        text: root.label
        color: area.containsMouse || root.accent ? Colors.notifTitle : Colors.notifBody
        font.family: Caelus.fontFamily
        font.pixelSize: Caelus.sizeBody
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
