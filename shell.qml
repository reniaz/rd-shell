import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.Services

PanelWindow {
    id: bar

    anchors { top: true; left: true; right: true }
    implicitHeight: 40
    color: "transparent"

    Poller {
        id: clock
        command: "date +%H:%M"
        interval: 30000
    }

    Poller {
        id: vol
        command: "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf\"%d\", $2*100}'"
        interval: 1000
    }

    Poller {
        id: net
        command: "nmcli -t -f NAME connection show --active | head -n1"
        interval: 5000
    }

    RowLayout {
        id: centerGroup
        anchors.centerIn: parent
        spacing: 8

        Pill {
            icon: "schedule"
            label: Time.time
            property bool timeOnly: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (parent.timeOnly) {
                        parent.label = Time.time + " | " + Time.date;
                    } else {
                        parent.label = Time.time;
                    }

                    parent.timeOnly = !parent.timeOnly;
                }
            }
        }
    }

    RowLayout {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 14
        spacing: 8

        Pill {
            icon: Audio.muted == false ? "volume_up" : "volume_off"
            label: Audio.percent + "%"
            iconColor: "#ffa478"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                onClicked: Audio.toggleMute()

                onWheel: wheel => Audio.setVolume(Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }

        Pill {
            icon: "lan"
            label: "ETH"
            iconColor: "#ff6048"
        }
    }
}
