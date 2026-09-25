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
    implicitWidth: osd.implicitWidth
    implicitHeight: osd.implicitHeight

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-kbosd"
    color: "transparent"

    // An empty region, so the card is not a 1.2s hole in the middle of whatever
    // you were clicking on. There is nothing here to interact with: the OSD
    // reports a switch that has already happened.
    mask: Region {}

    OsdCard {
        id: osd

        anchors.fill: parent
        // Cycling the layout again while the OSD is still up only restarts the
        // service's hold timer -- osdVisible never drops, so this window is not
        // rebuilt and the entrance is not replayed under a reader who is
        // mid-glance.
        shown: root.open && osd._entered

        property bool _entered: false
        Component.onCompleted: osd._entered = true

        RowLayout {
            anchors.fill: parent
            spacing: Caelus.spaceWide

            Text {
                text: "keyboard"
                color: Colors.keyboardIcon
                font.family: Caelus.symbolFamily
                font.pixelSize: 20
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                // The code is what the bar's pill already shows, so it leads
                // here too -- the OSD's own contribution is the name beside it.
                text: KeyboardLayout.code
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: 18
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: KeyboardLayout.keymap
                color: Colors.fgDim
                font.family: Caelus.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                visible: KeyboardLayout.keymap !== ""
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
