import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The per-filesystem breakdown behind the bar's disk pill. The card, its notch
// and the click-outside dismissal all belong to BarPopup; what is left here is
// the reading itself.
BarPopup {
    id: root

    namespace: "qs-disk"
    popupWidth: 280
    popupHeight: body.implicitHeight + 28

    // While the popup is up, the numbers in it are the only thing on screen, so
    // they are read at the rate they are watched. Gated on `open` rather than on
    // the window's lifetime: the loader now holds the window for the length of
    // the closing animation, and a card on its way out has no reader to serve.
    // Once it is gone the service falls back to its own ten-second cadence for
    // the pill.
    Timer {
        interval: 2000
        running: root.open
        repeat: true
        onTriggered: Disk.refresh()
    }

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "hard_drive"
                color: Colors.popupAccent
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
            }

            Text {
                text: "Disks"
                color: Colors.diskTitle
                font.family: "caelusevka"
                font.pixelSize: 15
            }

            Item { Layout.fillWidth: true }

            // The same used-of-total the rows print, summed over every device,
            // so the header answers "how full is this machine".
            Text {
                text: Format.human(Disk.totalUsed) + " / " + Format.human(Disk.totalSize)
                color: Colors.diskMeta
                font.family: "caelusevka"
                font.pixelSize: 13
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        // Counted rather than handed the array itself. df's result is republished
        // as a whole new array on every read, and a Repeater given that destroys
        // and rebuilds every row -- which throws away the very continuity the
        // easing below is for. A count changes only when a filesystem is actually
        // mounted or unmounted, so the rows now survive a refresh and move.
        Repeater {
            model: Disk.filesystems.length

            ColumnLayout {
                id: row

                required property int index

                // Undefined for the one binding pass between a filesystem going
                // away and the count catching up, so every read of it is guarded.
                readonly property var fs: Disk.filesystems[row.index]

                // The device is deliberately not printed: mount points are what a
                // partition is called when you use it, and /dev/dm-0 says nothing
                // that / and /home do not.
                readonly property color usage: Colors.usage(row.fs?.percent ?? 0, Colors.diskColor)

                // Animated here, on the reading, and not on the width of the bar
                // drawn from it: a Behavior on that width would also catch the
                // width the layout hands the track on its first polish pass, which
                // lands after this component is complete and its Behaviors are
                // live. Every bar would read that as a change and sweep up out of
                // nothing, so a popup rebuilt on each open would show the disks
                // filling rather than the disks as they stand.
                property real fraction: Math.min(1, (row.fs?.percent ?? 0) / 100)

                Behavior on fraction {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                Layout.fillWidth: true
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: (row.fs?.mounts ?? []).join("  ·  ")
                        color: Colors.diskTitle
                        font.family: "caelusevka"
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    Text {
                        text: (row.fs?.percent ?? 0) + "%"
                        color: row.usage
                        font.family: "caelusevka"
                        font.pixelSize: 14
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
                    color: Colors.diskTrack

                    // Follows the track exactly and instantly: the easing that
                    // makes a refresh read as the disk filling rather than as the
                    // popup redrawing lives on `fraction` above.
                    Rectangle {
                        width: Math.round(parent.width * row.fraction)
                        height: parent.height
                        radius: parent.radius
                        color: row.usage

                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: Format.human(row.fs?.used ?? 0) + " / " + Format.human(row.fs?.size ?? 0)
                        color: Colors.diskBody
                        font.family: "caelusevka"
                        font.pixelSize: 13
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: Format.human(row.fs?.avail ?? 0) + " free"
                        color: Colors.diskMeta
                        font.family: "caelusevka"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
