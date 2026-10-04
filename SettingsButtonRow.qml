import QtQuick
import QtQuick.Layouts
import qs.Config

// Kit component for the settings app: a row whose right-hand control is a
// labelled pill button rather than a switch, slider or segmented choice --
// "open the full switcher", "reload the shell", that kind of action, not a
// live setting. The contract's own suggestion for its colours --
// "Colors.element fill, Colors.elementActive on hover" -- names tokens that
// do not exist on Colors.qml (those two live only on Caelus.qml's *fixed*
// neutral ladder, which would stop the button following matugen); this
// reuses the idiom NotificationCard.qml's own action chips already settled
// on instead -- rest one tone below the card's own surface, hover up to the
// card's own hover tone -- rather than inventing a third pair of tokens for
// the same job.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string caption: ""
    property string buttonText: ""
    property string buttonIcon: ""

    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Math.max(52 * Caelus.uiScale, inner.implicitHeight + Caelus.spaceWide * 2)

    opacity: root.enabled ? 1 : 0.4
    Behavior on opacity { NumberAnimation { duration: Motion.base } }

    readonly property bool _hovered: rowHover.containsMouse

    Rectangle {
        anchors.fill: parent
        // ROUNDING RULE (user instruction): rows and their hover film are
        // square -- 0, never radiusCard. The button below is the one small
        // control on this row the rule carves a 4px exception out for.
        radius: 0
        color: root._hovered ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, Caelus.opacityHover) : "transparent"

        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    MouseArea {
        id: rowHover

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
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

        Rectangle {
            id: button

            implicitWidth: buttonInner.implicitWidth + Caelus.spaceWide * 2
            implicitHeight: 32 * Caelus.uiScale
            // ROUNDING RULE (user instruction): push buttons are one of the
            // named 4px exceptions -- radiusChip, never radiusPill/height-2.
            radius: Caelus.radiusChip
            color: (buttonArea.containsMouse || buttonFocus.activeFocus) ? Colors.surfaceHover : Colors.surface

            Behavior on color { ColorAnimation { duration: Motion.fast } }

            RowLayout {
                id: buttonInner

                anchors.centerIn: parent
                spacing: Caelus.spaceTight

                Text {
                    visible: root.buttonIcon !== ""
                    text: root.buttonIcon
                    color: Colors.fg
                    font.family: Caelus.symbolFamily
                    font.pixelSize: Caelus.sizeBody
                }

                Text {
                    text: root.buttonText
                    color: Colors.fg
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }
            }

            MouseArea {
                id: buttonArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { buttonFocus.forceActiveFocus(); root.clicked(); }
            }

            Item {
                id: buttonFocus

                anchors.fill: parent
                activeFocusOnTab: true

                Keys.onReturnPressed: root.clicked()
                Keys.onSpacePressed: root.clicked()
            }

            FocusRing {
                anchors.fill: parent
                anchors.margins: -4
                radius: Caelus.radiusChip
                show: buttonFocus.activeFocus
            }
        }
    }
}
