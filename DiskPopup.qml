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
    // they are read at the rate they are watched. The loader destroys this
    // window on close, which takes the timer with it -- the service falls back
    // to its own ten-second cadence for the pill.
    Timer {
        interval: 2000
        running: true
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
                color: Colors.diskIcon
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

        Repeater {
            model: Disk.filesystems

            ColumnLayout {
                id: row

                required property var modelData

                // The device is deliberately not printed: mount points are what a
                // partition is called when you use it, and /dev/dm-0 says nothing
                // that / and /home do not.
                readonly property color usage: Colors.usage(row.modelData.percent, Colors.diskColor)

                Layout.fillWidth: true
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.mounts.join("  ·  ")
                        color: Colors.diskTitle
                        font.family: "caelusevka"
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    Text {
                        text: row.modelData.percent + "%"
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

                    // Animated so a refresh under the reader's eyes reads as the
                    // disk filling rather than as the popup redrawing.
                    Rectangle {
                        width: Math.round(parent.width * Math.min(1, row.modelData.percent / 100))
                        height: parent.height
                        radius: parent.radius
                        color: row.usage

                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: Format.human(row.modelData.used) + " / " + Format.human(row.modelData.size)
                        color: Colors.diskBody
                        font.family: "caelusevka"
                        font.pixelSize: 13
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: Format.human(row.modelData.avail) + " free"
                        color: Colors.diskMeta
                        font.family: "caelusevka"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
