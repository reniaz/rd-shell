import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The live half of roadmap §7.6: a small, hand-picked surface over the
// settings a person actually reaches for. For now that is none -- the
// dynamic colour switch was taken off the card, colour simply follows the
// wallpaper -- so what is left is the header and the power section. The
// card and the click-outside dismissal both belong to BarPopup, same as
// every other popup on this bar.
//
// Also the one menu behind the bar's `✦` pill: the settings and power
// pills used to open separate windows, and now open this one instead, with
// PowerMenu.qml embedded as a section at the bottom -- see its own header
// for why the confirm flow that used to justify a dedicated window did not
// need one. Both halves open and close on the same flag, Power.menuOpen,
// which is what keeps the Super+M keybind and the IPC call in hyprland.lua
// working unchanged.
BarPopup {
    id: root

    namespace: "qs-settings"
    popupWidth: 320

    // As tall as the content needs and no taller than the screen allows --
    // the same idiom SysPopup uses. The screen cap only starts applying once
    // there is a screen height to cap against: a layer surface is told its
    // size a round trip after creation, so root.height is zero for the first
    // few frames, and an unguarded Math.min against that would open the card
    // at the floor and then grow.
    popupHeight: root.height > 0
        ? Math.min(root.height - (Caelus.barHeight - Caelus.barInset + Caelus.spaceEdge), body.implicitHeight + 28)
        : body.implicitHeight + 28

    // Belt-and-braces alongside whatever the loader that embeds this wires
    // its own onDismissed to: a Connections block, not `onDismissed:` on the
    // root itself, so this still fires even if a caller also sets its own
    // handler on the instance -- the two do not compete for the same slot.
    Connections {
        target: root

        function onDismissed() { Power.menuOpen = false; }
    }


    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Caelus.spaceEdge
        spacing: Caelus.spaceWide

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.space

            // The shell's own mark rather than a gear, and the same glyph the
            // bar pill that opens this carries -- a plain Unicode star, so it
            // comes from caelusevka and not from the icon font every other
            // popup header draws from. It runs larger than those for the same
            // reason the bar pill's does: the star fills far less of its em
            // box than a Material Symbol fills of its own.
            Text {
                text: "✦"
                color: Colors.popupAccent
                font.family: Caelus.fontFamily
                font.pixelSize: 20
            }

            Text {
                text: "rd ✦ shell"
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLead
            }

            Item { Layout.fillWidth: true }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        // Shutting down and logging out are the only irreversible controls
        // in this shell, so they sit behind the same divider idiom as every
        // other popup's sections. The dynamic colour toggle that used to sit
        // above them is off the card for now: dynamic colour is simply on
        // (Services/Settings.qml defaults it to true), and the setting itself
        // is still there for the card to grow back a switch for.
        PowerMenu {
            Layout.fillWidth: true
        }
    }
}
