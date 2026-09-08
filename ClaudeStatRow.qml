import QtQuick
import QtQuick.Layouts
import qs.Config

// One "label …… value" line. fillWidth is set here rather than at each of the
// twenty-odd call sites, since a stat row that does not span its section is
// never what anyone wants.
RowLayout {
    id: root

    property string label
    property string value
    property color valueColor: Colors.claudeTitle

    // Secondary rows read as one muted line instead of a heading with a figure
    // beside it, so the value drops to the label's own weight.
    property bool dim: false

    Layout.fillWidth: true
    spacing: 8

    Text {
        text: root.label
        color: Colors.claudeBody
        font.family: "caelusevka"
        font.pixelSize: 13
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    Text {
        text: root.value
        color: root.dim ? Colors.claudeMeta : root.valueColor
        font.family: "caelusevka"
        font.pixelSize: 13
    }
}
