import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// Same card shape as KeyboardLayoutOsd.qml and BrightnessOsd.qml -- read
// those first. LockKeys.mode says which key just flipped; the state shown
// is read live off LockKeys itself rather than captured once at open, the
// same reasoning BrightnessOsd.qml's own `mode`/`percent` split documents --
// a second flip of the same key while this window is still up (PopupLoader
// keeps it alive through its hold, see PopupLoader.qml) updates the same
// card instead of tearing it down and replaying the entrance.
PanelWindow {
    id: root

    // Written by the PopupLoader that owns this window; true by default
    // because the window exists before its loader can reach it -- see
    // KeyboardLayoutOsd.qml.
    property bool open: true
    property bool _entered: false

    readonly property bool caps: LockKeys.mode === "caps"
    readonly property bool state: root.caps ? LockKeys.capsOn : LockKeys.numOn

    // Deliberately no anchors, same as KeyboardLayoutOsd.qml: an unanchored
    // layer surface is centred by the compositor, so the window is exactly
    // the card.
    implicitWidth: osd.implicitWidth
    implicitHeight: osd.implicitHeight

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-lockkeysosd"
    color: "transparent"

    // Empty region, same as every other OSD here: this reports a toggle
    // that already happened, there is nothing on it to click.
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
                // "keyboard_capslock" is a real Material Symbols glyph;
                // Num Lock has no dedicated one, so "numbers" (a 1-2-3
                // grid) stands in the same way an unmatched app class falls
                // back to "apps" in WorkspaceDots.qml's glyph table.
                text: root.caps ? "keyboard_capslock" : "numbers"
                color: Colors.accent
                font.family: Caelus.symbolFamily
                font.pixelSize: 20
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: (root.caps ? "Caps Lock " : "Num Lock ") + (root.state ? "on" : "off")
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: 16
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
            }
        }
    }
}
