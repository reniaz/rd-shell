import QtQuick
import QtQuick.Layouts
import qs.Config

// Kit component for the settings app: a full-width row -- icon, label,
// optional wrapping caption, a SettingsSwitch at the right -- that toggles
// from a click anywhere on it, not just on the switch itself. The row owns
// one MouseArea covering the whole thing rather than letting clicks fall
// through to the switch's own (SettingsSwitch.qml has one too, for when it
// is used bare): the row's MouseArea is declared after the switch in the
// tree, so it sits on top and is the only thing a mouse click ever reaches,
// which is what keeps a click from firing both MouseAreas' `toggled()` and
// flipping the row twice. Tab still lands on the switch directly, since
// activeFocusOnTab lives there and mouse z-order has no bearing on keyboard
// focus traversal.
//
// This row never writes `checked` itself -- `checked` is bound in from
// whichever page owns the real Settings.* property, and this only ever
// emits `toggled()` for that page to act on.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string caption: ""
    property bool checked: false

    signal toggled()

    Layout.fillWidth: true
    implicitHeight: Math.max(52 * Caelus.uiScale, inner.implicitHeight + Caelus.spaceWide * 2)

    opacity: root.enabled ? 1 : 0.4
    Behavior on opacity { NumberAnimation { duration: Motion.base } }

    readonly property bool _hovered: hoverArea.containsMouse

    Rectangle {
        anchors.fill: parent
        // ROUNDING RULE (user instruction): rows and their hover film are
        // square -- 0, never radiusCard.
        radius: 0
        color: root._hovered ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, Caelus.opacityHover) : "transparent"

        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    RowLayout {
        id: inner

        anchors.fill: parent
        anchors.margins: Caelus.spaceWide
        spacing: Caelus.space

        Text {
            visible: root.icon !== ""
            text: root.icon
            color: Colors.fgDim
            font.family: Caelus.symbolFamily
            font.pixelSize: Caelus.sizeTitle
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.label
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
            }

            Text {
                Layout.fillWidth: true
                visible: root.caption !== ""
                text: root.caption
                color: Colors.fgMuted
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
                wrapMode: Text.WordWrap
            }
        }

        SettingsSwitch {
            id: switchControl

            checked: root.checked

            onToggled: root.toggled()
        }
    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: { switchControl.forceActiveFocus(); root.toggled(); }
    }
}
