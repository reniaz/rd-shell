import QtQuick
import qs.Config

// Kit component for the settings app: the animated pill switch every toggle
// row uses. It owns its own focus and key handling -- SettingsToggleRow just
// places one and reads `checked`/`toggled()` -- so a bare SettingsSwitch
// dropped anywhere (a test harness, a future row type) is already a
// complete, keyboard-reachable control on its own, per the contract's "every
// control is keyboard reachable and drops a FocusRing inside itself" rule.
//
// The knob's on-colour is Colors.onAccent (Wal.onPrimary under matugen), not
// Caelus.textOnAccent, which is the *fixed*-theme token and would stop
// following the wallpaper.
//
// ROUNDING RULE (user instruction): max radius anywhere in the settings app
// is Caelus.radiusChip (4), the one exception carved out for small controls
// like this switch -- everything else in the kit is square. The knob stays
// inset by the same margin it always was; at 4px on an 18px knob inside a
// 24px-tall, 4px track, a plain rounded square reads as a deliberately
// smaller echo of the track's own corner rather than as a mismatched circle.
Item {
    id: root

    property bool checked: false

    signal toggled()

    implicitWidth: 44 * Caelus.uiScale
    implicitHeight: 24 * Caelus.uiScale

    activeFocusOnTab: true

    Keys.onReturnPressed: root.toggled()
    Keys.onSpacePressed: root.toggled()

    Rectangle {
        id: track

        anchors.fill: parent
        radius: Caelus.radiusChip
        color: root.checked ? Colors.popupAccent : Colors.surfaceHover

        Behavior on color { ColorAnimation { duration: Motion.base; easing.type: Motion.standard } }

        Rectangle {
            id: knob

            readonly property real margin: 3 * Caelus.uiScale

            width: track.height - margin * 2
            height: width
            radius: Caelus.radiusChip
            y: margin
            x: root.checked ? track.width - margin - width : margin
            color: root.checked ? Colors.onAccent : Colors.fgMuted

            Behavior on x { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
            Behavior on color { ColorAnimation { duration: Motion.base; easing.type: Motion.standard } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.forceActiveFocus(); root.toggled(); }
    }

    FocusRing {
        anchors.fill: parent
        anchors.margins: -4
        radius: Caelus.radiusChip
        show: root.activeFocus
    }
}
