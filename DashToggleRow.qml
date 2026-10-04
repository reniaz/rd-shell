import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The dashboard's top row: five quick-toggle chips, Ambxst-reference style
// (ocr-colorpicker-qr-utility-tray-1.png) -- a glyph over a short label, lit
// when the thing it names is on.
//
// Only Wi-Fi has anywhere to read a real state from today (Services/
// Network.qml, read-only -- that service has no enable/disable call of its
// own, only `openSettings()`, so this chip opens the NetworkManager editor
// rather than pretending to toggle a radio nothing here can actually drive).
// Bluetooth and the three environment toggles are deliberate stubs: nothing
// in this shell talks to bluetoothd, a night-light compositor rule, an
// idle-inhibitor or a game-mode switch yet, so each one shows its icon dim
// and disabled rather than a control that lies about what pressing it does.
RowLayout {
    id: root

    spacing: Caelus.space

    component Chip: Rectangle {
        id: chip

        required property string glyph
        required property string label
        property bool on: false
        property bool available: true

        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Caelus.radiusCard
        color: chip.on ? Colors.popupAccent : (hover.hovered ? Colors.surfaceHover : Colors.calField)
        border.width: 1
        border.color: chip.on ? Colors.popupAccent : Colors.calFieldBorder
        opacity: chip.available ? 1 : 0.4

        Behavior on color { ColorAnimation { duration: Motion.fast } }

        HoverHandler { id: hover; enabled: chip.available }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: chip.glyph
                color: chip.on ? Colors.onAccent : Colors.calMeta
                font.family: Caelus.symbolFamily
                font.pixelSize: 18
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: chip.label
                color: chip.on ? Colors.onAccent : Colors.calMeta
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: chip.available
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    Chip {
        glyph: Network.connected ? "wifi" : "wifi_off"
        label: Network.connected ? (Network.name !== "" ? Network.name : "Online") : "Offline"
        on: Network.connected
        onClicked: Network.openSettings()
    }

    // No Bluetooth service exists in this shell yet -- shown, not hidden, so
    // the row's shape stays the same five-wide grid the reference image
    // shows, with a glyph that already reads as "radio" rather than nothing.
    Chip {
        glyph: "bluetooth"
        label: "Bluetooth"
        available: false
    }

    // Three environment stubs, `enabled: false` with no backend behind any
    // of them yet (deliberate -- see the file comment above). Local `on`
    // state only, never read by anything, so flipping the constant to true
    // here previews the lit look without claiming a feature that isn't
    // wired up.
    Chip {
        glyph: "dark_mode"
        label: "Night light"
        available: false
    }

    Chip {
        glyph: "bedtime_off"
        label: "Caffeine"
        available: false
    }

    Chip {
        glyph: "stadia_controller"
        label: "Game mode"
        available: false
    }
}
