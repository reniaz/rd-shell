import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// One card, two pills: `capture` is the only thing that tells the output
// card from the input card, since a sink and a source are the same shape of
// problem -- pick a default device, set its level, set each app's level.
BarPopup {
    id: root

    property bool capture: false

    namespace: root.capture ? "qs-mic" : "qs-audio"
    popupWidth: 320
    popupHeight: body.implicitHeight + 28

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 10

        // The master level for whichever half of the machine this card is
        // about, and the whole heading: the glyph already says microphone or
        // speaker, and the pill it hangs from said it before the card opened.
        VolumeSlider {
            Layout.fillWidth: true
            value: root.capture ? Audio.micVolume : Audio.volume
            muted: root.capture ? Audio.micMuted : Audio.muted
            icon: root.capture ? "mic" : "volume_down"
            mutedIcon: root.capture ? "mic_off" : "volume_off"
            onMoved: v => root.capture ? Audio.setMicVolume(v) : Audio.setVolume(v)
            onToggled: root.capture ? Audio.toggleMicMute() : Audio.toggleMute()
            onStepped: delta => {
                const current = root.capture ? Audio.micVolume : Audio.volume;
                if (root.capture) Audio.setMicVolume(current + delta);
                else Audio.setVolume(current + delta);
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        Text {
            Layout.topMargin: 4
            text: "Devices"
            color: Colors.audioMeta
            font.family: "caelusevka"
            font.pixelSize: 12
        }

        Repeater {
            model: root.capture ? Audio.sources : Audio.sinks

            Rectangle {
                id: deviceRow

                required property var modelData

                // The row wearing the outline is the device PipeWire will
                // actually use next -- same "this is the one" language the
                // media card gives the player that is sounding.
                readonly property bool isDefault: deviceRow.modelData === (root.capture ? Audio.source : Audio.sink)

                Layout.fillWidth: true
                implicitHeight: deviceLine.implicitHeight + 16
                radius: 12
                color: hoverArea.containsMouse ? Colors.surfaceHover : Colors.audioCard
                border.width: 1
                border.color: deviceRow.isDefault ? Colors.audioActive : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }

                MouseArea {
                    id: hoverArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.capture
                        ? Audio.setDefaultSource(deviceRow.modelData)
                        : Audio.setDefaultSink(deviceRow.modelData)
                }

                RowLayout {
                    id: deviceLine

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: root.capture ? "mic" : "speaker"
                        color: deviceRow.isDefault ? Colors.audioActive : Colors.audioMeta
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 16
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Audio.nodeLabel(deviceRow.modelData)
                        color: Colors.audioTitle
                        font.family: "caelusevka"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Text {
            Layout.topMargin: 4
            text: "Apps"
            color: Colors.audioMeta
            font.family: "caelusevka"
            font.pixelSize: 12
        }

        Repeater {
            model: root.capture ? Audio.sourceStreams : Audio.sinkStreams

            Rectangle {
                id: appRow

                required property var modelData

                // A stream PipeWire has not finished binding yet has no
                // audio to read or write -- same guard the media card puts
                // on `adjustable`.
                readonly property bool ready: appRow.modelData?.ready ?? false

                Layout.fillWidth: true
                implicitHeight: appLine.implicitHeight + 16
                radius: 12
                color: Colors.audioCard

                RowLayout {
                    id: appLine

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: "apps"
                        color: Colors.audioMeta
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 16
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: Audio.appLabel(appRow.modelData)
                            color: Colors.audioTitle
                            font.family: "caelusevka"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        VolumeSlider {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            visible: appRow.ready
                            value: appRow.modelData?.audio?.volume ?? 0
                            muted: appRow.modelData?.audio?.muted ?? false
                            onMoved: v => Audio.setNodeVolume(appRow.modelData, v)
                            onToggled: Audio.toggleNodeMute(appRow.modelData)
                            onStepped: delta => Audio.stepNodeVolume(appRow.modelData, delta)
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            text: root.capture ? "Nothing is recording" : "Nothing is playing"
            color: Colors.audioMeta
            font.family: "caelusevka"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            visible: (root.capture ? Audio.sourceStreams.length : Audio.sinkStreams.length) === 0
        }
    }
}
