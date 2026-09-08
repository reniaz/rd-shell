import QtQuick
import QtQuick.Layouts
import qs.Config

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color iconColor: Colors.accent
    property int maxLabelWidth: 400
    property alias content: row.data

    implicitWidth: row.implicitWidth + 22
    implicitHeight: 32
    radius: height / 2
    color: Colors.bg

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
