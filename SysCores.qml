import QtQuick
import QtQuick.Layouts
import qs.Config

// One column per logical core, filling from the bottom. A twelve-core machine
// running one thread flat out and a twelve-core machine at 8% average are the
// same number on the CPU meter above and nothing alike, and this is the
// cheapest drawing that tells them apart.
RowLayout {
    id: root

    property var cores: []
    property int thickness: 22

    Layout.fillWidth: true
    spacing: 3

    Repeater {
        model: root.cores

        Rectangle {
            id: column

            required property int modelData

            Layout.fillWidth: true
            implicitHeight: root.thickness
            radius: 3
            color: Colors.sysTrack

            Rectangle {
                width: parent.width
                height: Math.max(2, Math.round(parent.height * column.modelData / 100))
                anchors.bottom: parent.bottom
                radius: parent.radius
                color: Colors.usage(column.modelData, Colors.sysColor)

                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
    }
}
