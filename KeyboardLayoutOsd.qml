import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The layout you just switched to, said once in the middle of the screen you
// are looking at. Which screen that is belongs to Bar, which only loads this on
// the focused monitor -- the same rule the power menu and the panels follow.
PanelWindow {
    id: root

    // Written by the PopupLoader that owns this window, which keeps it alive
    // past the moment KeyboardLayout.osdVisible drops -- see PopupLoader.qml.
    // True by default because the window exists before its loader can reach it.
    property bool open: true

    // Raised once the window exists, so the fade below has a collapsed first
    // frame to start from.
    property bool _entered: false

    // Deliberately no anchors. A layer surface left unanchored on both axes is
    // centred by the compositor, so the window is exactly the card and sits in
    // the middle without this having to know the screen's size.
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-kbosd"
    color: "transparent"

    // An empty region, so the card is not a 1.2s hole in the middle of whatever
    // you were clicking on. There is nothing here to interact with: the OSD
    // reports a switch that has already happened.
    mask: Region {}

    Rectangle {
        id: card

        anchors.fill: parent
        implicitWidth: Math.max(220, content.implicitWidth + 64)
        implicitHeight: content.implicitHeight + 46
        // Square, and bordered in the accent every other surface on this bar is
        // outlined with, so the OSD reads as part of the shell rather than as a
        // notification from whatever changed the layout.
        radius: 0
        color: Colors.surface
        border.width: 1
        border.color: Colors.accent

        // The OSD now leaves the way it arrived. This used to be a one-shot
        // assignment, because the window was torn down the instant osdVisible
        // dropped and a fade-out bound to it would never have been seen; the
        // loader holds it open long enough for the second half to play, so the
        // opacity can go back to being a binding on the state.
        //
        // Cycling the layout again while the OSD is still up only restarts the
        // service's hold timer -- osdVisible never drops, so this window is not
        // rebuilt and the fade is not replayed under a reader who is mid-glance.
        opacity: (root._entered && root.open) ? 1 : 0

        Component.onCompleted: root._entered = true

        Behavior on opacity { NumberAnimation { duration: 140 } }

        // Layouts and not Column/Row: a Column ignores the horizontalCenter
        // anchor on its children, so the code line was left-aligned against the
        // wider layout name instead of centred over it.
        ColumnLayout {
            id: content

            anchors.centerIn: parent
            spacing: 6

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14

                Text {
                    text: "keyboard"
                    color: Colors.keyboardIcon
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 48
                }

                Text {
                    text: KeyboardLayout.code
                    color: Colors.fg
                    font.family: "caelusevka"
                    font.pixelSize: 48
                }
            }

            // The code is what the pill shows, so the name is what the OSD adds.
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: KeyboardLayout.keymap
                color: Colors.fgDim
                font.family: "caelusevka"
                font.pixelSize: 19
                visible: KeyboardLayout.keymap !== ""
            }
        }
    }
}
