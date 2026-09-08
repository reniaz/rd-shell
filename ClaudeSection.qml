import QtQuick
import QtQuick.Layouts
import qs.Config

// The titled card that every panel section is made of. It was copy-pasted
// seven times in the old ClaudePanel, which is why the radius and the border
// had already drifted apart between two of them.
Rectangle {
    id: root

    property string title
    property string trailing

    // Aliased to the inner layout's `data` rather than to the layout itself, so
    // callers pass plain children and never have to know the container exists.
    default property alias content: inner.data

    implicitHeight: inner.implicitHeight + 26
    radius: 14
    color: Colors.claudeCardBg
    border.width: 1
    border.color: Colors.claudeBorder

    ColumnLayout {
        id: inner

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.title !== "" || root.trailing !== ""

            Text {
                text: root.title
                color: Colors.claudeMeta
                font.family: "caelusevka"
                font.pixelSize: 13
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.trailing
                color: Colors.claudeMeta
                font.family: "caelusevka"
                font.pixelSize: 13
                visible: text !== ""
            }
        }
    }
}
