import QtQuick
import QtQuick.Layouts
import qs.Config

// One segment of the bar. It used to draw itself as a rounded island, which is
// where the name comes from; the bar is one solid surface now, so a segment
// draws nothing of its own and is only the spacing and the two texts.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color iconColor: Colors.accent
    property int maxLabelWidth: 400
    property alias content: row.data

    implicitWidth: row.implicitWidth + 18
    implicitHeight: 32
    color: "transparent"

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Text {
            text: root.icon
            color: root.iconColor
            font.family: "Material Symbols Rounded"
            font.pixelSize: 16
            visible: root.icon !== ""
        }

        Text {
            text: root.label
            color: Colors.fg
            font.family: "caelusevka"
            font.pixelSize: 16
            elide: Text.ElideRight
            Layout.maximumWidth: root.maxLabelWidth
            visible: root.label !== ""
        }
    }
}
