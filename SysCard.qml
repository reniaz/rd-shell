import QtQuick
import QtQuick.Layouts
import qs.Config

// One titled block of the system popup. The trailing side is a slot rather than
// a string because these headings carry readings and controls, not only labels.
Rectangle {
    id: root

    property string title
    property alias trailing: trailingRow.data

    default property alias content: inner.data

    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + 24

    // Everything but the content: padding, title row and the gap under it.
    // For a card that sizes its content from the room it has (SysProcList).
    readonly property real chromeHeight: 24 + headRow.implicitHeight + inner.spacing
    radius: Caelus.radiusPopover
    color: Colors.sysCard
    border.width: 1
    border.color: Colors.popupBorder

    ColumnLayout {
        id: inner

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 13
        anchors.rightMargin: 13
        spacing: Caelus.space

        RowLayout {
            id: headRow

            Layout.fillWidth: true
            spacing: Caelus.space

            Text {
                text: root.title
                color: Colors.sysMeta
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            RowLayout {
                id: trailingRow
                spacing: Caelus.space
            }
        }
    }
}
