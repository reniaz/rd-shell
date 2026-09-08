import QtQuick
import QtQuick.Layouts
import qs.Config

// One "label …… value" line inside a card. fillWidth is set here rather than at
// each call site, since a stat row that does not span its card is never what
// anyone wants.
RowLayout {
    id: root

    property string label
    property string value
    property color valueColor: Colors.sysBody

    Layout.fillWidth: true
    spacing: 8

    Text {
        text: root.label
        color: Colors.sysMeta
        font.family: "caelusevka"
        font.pixelSize: 12
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    Text {
        text: root.value
        color: root.valueColor
        font.family: "caelusevka"
        font.pixelSize: 12
    }
}
