import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// Same card shape as KeyboardLayoutOsd.qml and VolumeOsd.qml -- read those
// first. Unlike Audio, Brightness.qml is this fan-out's own singleton, so it
// raises osdVisible itself exactly the way KeyboardLayout.qml does, and
// Bar.qml gates this window on that flag together with Brightness.available:
// a machine with no backlight device -- this one has none, its outputs are
// DP-1/DP-2 -- never creates this window at all.
PanelWindow {
    id: root

    property bool open: true
    property bool _entered: false

    // Which display property this card is about. Brightness reads itself
    // straight off its own singleton and is the default, so every existing
    // call site is unchanged; contrast has no singleton of its own and is
    // handed its number by BarContrastWatch.qml instead. One window for both,
    // the same arrangement AudioOsd.qml has for the sink and the source:
    // nudging contrast while the brightness card is still up has to replace
    // it, not stack a second card on top.
    property string mode: "brightness"
    readonly property bool contrast: root.mode === "contrast"

    property int percent: root.contrast ? 0 : Brightness.percent
    property real fraction: root.contrast ? root.percent / 100 : Brightness.brightness

    implicitWidth: osd.implicitWidth
    implicitHeight: osd.implicitHeight

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: root.contrast ? "qs-contrastosd" : "qs-brightnessosd"
    color: "transparent"

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

            Text {
                // Brightness has three glyphs so the icon alone carries
                // roughly where the level sits; contrast's own symbol is a
                // half-filled disc that has no such ladder, and inventing one
                // out of unrelated icons would say less than the bar beside
                // it already does.
                text: root.contrast ? "contrast"
                    : root.percent < 34 ? "brightness_low"
                    : root.percent < 67 ? "brightness_medium" : "brightness_high"
                color: Colors.accent
                font.family: Caelus.symbolFamily
                font.pixelSize: 20
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                id: track

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 5
                radius: Caelus.radiusPill
                color: Colors.brightnessTrack

                Rectangle {
                    width: Math.round(track.width * root.fraction)
                    height: parent.height
                    radius: parent.radius
                    color: Colors.accent

                    Behavior on width {
                        NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
                    }
                }
            }

            Text {
                text: root.percent + "%"
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: 14
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: 44
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
