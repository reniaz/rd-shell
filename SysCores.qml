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
        // A count, and the array read through it -- not the array itself. A
        // Repeater handed a JavaScript array throws every delegate away and
        // builds them again the moment that array is replaced, and SysMon
        // publishes a whole new one on every poll. The columns would be
        // destroyed and recreated already at their new height, so the easing
        // below could never run: the load would flick between frames instead
        // of sliding. A core count only changes when the machine does, so
        // this keeps each column alive and lets its own binding move it.
        model: root.cores.length

        Rectangle {
            id: column

            required property int index

            readonly property int load: root.cores[column.index] ?? 0

            // The share of the column that is filled, eased here rather than on
            // the height drawn from it below. That height reads `parent.height`,
            // and this column is a RowLayout child, so its geometry is handed
            // down on the layout's first polish pass -- which happens after the
            // delegate is complete and its Behaviors are therefore live. A
            // Behavior on the height would read that first assignment as a
            // change and run all twenty-four columns up out of the floor every
            // time the popup is built, so a reopened system popup would show the
            // machine starting up rather than the machine as it is. Animating
            // the reading leaves the opening frame exact and keeps the easing
            // for the polls that genuinely move it.
            property real fraction: column.load / 100

            Behavior on fraction {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Layout.fillWidth: true
            implicitHeight: root.thickness
            radius: 3
            color: Colors.sysTrack

            // Follows the column exactly and instantly, with two pixels of floor
            // so an idle core is still a mark. The colour is eased over the same
            // 120ms the Claude meters use, against the 220ms above: a core
            // crossing a usage threshold should not be seen to finish changing
            // colour well before it has finished changing length.
            Rectangle {
                width: parent.width
                height: Math.max(2, Math.round(parent.height * Math.min(1, column.fraction)))
                anchors.bottom: parent.bottom
                radius: parent.radius
                color: Colors.usage(column.load, Colors.sysColor)

                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }
}
