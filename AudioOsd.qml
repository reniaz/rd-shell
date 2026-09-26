import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// One window for both audio levels. The sink and the microphone are never
// worth two cards: they are centred on the same screen, so two of them would
// land on top of each other the moment you muted the mic while the volume
// card was still up. `mode` says which of the two this pulse is about, and
// the window is torn down and rebuilt between pulses anyway.
PanelWindow {
    id: root

    // "sink" or "source". Written by the PopupLoader in Bar.qml from the same
    // watcher that decides the window should exist at all.
    property string mode: "sink"

    // Written by the PopupLoader that owns this window, which keeps it alive
    // past the moment the pulse drops so the fade-out has time to run.
    property bool open: true

    readonly property bool mic: root.mode === "source"
    readonly property bool muted: root.mic ? Audio.micMuted : Audio.muted
    readonly property int percent: root.mic ? Audio.micPercent : Audio.percent
    readonly property real level: root.mic ? Audio.micVolume : Audio.volume
    // The microphone keeps its own colour rather than borrowing the sink's.
    // Mic red and volume green are the two colours on this bar that are read
    // without being looked at, and an OSD is exactly the moment that matters.
    readonly property color tint: root.mic ? Colors.micColor : Colors.volumeColor

    // Deliberately no anchors: an unanchored layer surface is centred by the
    // compositor, so the window is exactly the card.
    implicitWidth: osd.implicitWidth
    implicitHeight: osd.implicitHeight

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-audioosd"
    color: "transparent"

    // Nothing here is clickable -- it reports a change that has already
    // happened -- so it must not be a hole in whatever is underneath.
    mask: Region {}

    OsdCard {
        id: osd

        anchors.fill: parent
        shown: root.open && osd._entered

        property bool _entered: false
        Component.onCompleted: osd._entered = true

        RowLayout {
            anchors.fill: parent
            spacing: Caelus.spaceWide

            MuteGlyph {
                // volume_mute is a different glyph from volume_down/up on
                // purpose: 0% still means the sink is live and would be heard
                // the moment it is turned up. Muted no longer swaps to
                // volume_off/mic_off either -- the level-held glyph stays and
                // MuteGlyph's slash overlays it, so the glyph and the bar
                // below agree on the same held level at a glance.
                glyph: root.mic
                    ? "mic"
                    : root.percent === 0 ? "volume_mute"
                        : root.percent < 50 ? "volume_down" : "volume_up"
                muted: root.muted
                color: root.muted ? Colors.fgMuted : root.tint
                size: 20
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                id: track

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 5
                radius: Caelus.radiusPill
                color: Colors.audioTrack

                Rectangle {
                    // Held at the real level while muted rather than zeroed.
                    // "Silenced at 60%" is what unmuting restores, and a bar
                    // collapsed to nothing says the opposite.
                    width: Math.round(track.width * root.level)
                    height: parent.height
                    radius: parent.radius
                    color: root.muted ? Colors.fgMuted : root.tint

                    Behavior on width {
                        NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
                    }
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }
            }

            Text {
                text: root.muted ? "Muted" : root.percent + "%"
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: 14
                horizontalAlignment: Text.AlignRight
                // Fixed width so the track does not twitch sideways as the
                // number goes from two digits to three.
                Layout.minimumWidth: 44
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
