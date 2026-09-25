import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The desktop layer proper: a giant clock and, under it, the now-playing
// card -- what caelestia-shell calls its desktop widgets, seen on an empty
// workspace or through the gaps between tiled windows. Sits above
// Wallpaper's own Background layer and below every real window
// (WlrLayer.Bottom is the layer between the two), so it never competes with
// anything actually being worked in. One per screen, the same idiom
// Wallpaper, BarWindow and EdgeBar already use from shell.qml.
PanelWindow {
    id: root

    required property var modelData

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-desktop"
    color: "transparent"

    // The whole window, not just its content -- an invisible-but-mapped
    // surface would still be a full-screen layer the compositor keeps
    // around and asks for input, for widgets nobody can see.
    visible: Settings.desktopWidgets

    // Only the now-playing card ever takes a click (DesktopMedia's own
    // `shown` -- see the contract in the scratchpad). The clock and the rest
    // of the desktop must fall straight through to whatever is underneath,
    // the same "never the thing a click lands on" rule Wallpaper.qml's own
    // permanently-empty mask follows -- an absent `item` is Region's empty
    // case, so hiding the card (or it never having appeared) empties this
    // exactly the way Wallpaper's `emptyRegion` does.
    mask: Region { item: media.shown ? media : null }

    // Top-right corner, right-aligned, clear of the bar strip above it.
    // EdgeBar puts its hover strip on whichever side is this screen's true
    // outer edge (left *or* right, decided by geometry, and only 6px + a 48px
    // card even at its widest) -- 72px clears that either way without having
    // to ask EdgeBar which side it picked for this particular screen.
    ColumnLayout {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Caelus.barHeight + 40
        anchors.rightMargin: 72
        spacing: Caelus.spaceEdge

        DesktopClock {}

        DesktopMedia {
            id: media
            Layout.alignment: Qt.AlignRight
        }
    }
}
