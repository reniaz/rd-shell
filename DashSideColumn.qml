import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The dashboard's right column: brightness on its own vertical track
// (EdgeSlider.qml -- the same control the edge panel already drags DDC with,
// reused rather than a second vertical slider written for just this card),
// and volume/mic each on the horizontal row VolumeSlider.qml already gives
// every other volume control in this shell.
ColumnLayout {
    id: root

    spacing: Caelus.spaceLoose

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 120
        radius: Caelus.radiusCard
        color: Colors.calField
        border.width: 1
        border.color: Colors.calFieldBorder
        visible: Brightness.available

        EdgeSlider {
            anchors.fill: parent
            anchors.margins: Caelus.spaceLoose
            value: Brightness.brightness
            accent: Colors.popupAccent
            icon: "brightness_6"
            onMoved: v => Brightness.set(v * 100)
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Caelus.spaceLoose

        VolumeSlider {
            Layout.fillWidth: true
            value: Audio.volume
            muted: Audio.muted
            icon: "volume_up"
            accent: Colors.volumeColor
            onMoved: v => Audio.setVolume(v)
            onToggled: Audio.toggleMute()
            onStepped: delta => Audio.setVolume(Audio.volume + delta)
        }

        VolumeSlider {
            Layout.fillWidth: true
            visible: Audio.micReady
            value: Audio.micVolume
            muted: Audio.micMuted
            icon: "mic"
            accent: Colors.micColor
            onMoved: v => Audio.setMicVolume(v)
            onToggled: Audio.toggleMicMute()
            onStepped: delta => Audio.setMicVolume(Audio.micVolume + delta)
        }
    }
}
