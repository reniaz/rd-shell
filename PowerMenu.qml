import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The power half of the merged menu -- see SettingsPopup.qml's header for
// why the two live in one card now. This used to be its own full-screen
// PanelWindow with a confirm step guarding the two destructive actions; the
// window is gone (SettingsPopup's BarPopup card is the only window now), but
// the two-stage flow it existed for is not: "choose" still lists
// Power.actions, "confirm" still asks the pending action's own question, and
// only a second, explicit click on "Yes" still runs one. Everything that
// flow needs -- stage, pending, the reset-on-open guard -- stays local to
// this file, so SettingsPopup only has to embed it, not know how it works.
ColumnLayout {
    id: root

    spacing: Caelus.space

    property string stage: "choose"
    property var pending: null

    // A menu that reopens still showing "Shut down?" from the last time it
    // was up is how someone shuts their machine down by accident, so every
    // open snaps this back to the safe stage regardless of how the last one
    // ended. Power.menuOpen is the one flag the whole merged card opens and
    // closes on -- see SettingsPopup.qml -- so watching it here is enough.
    Connections {
        target: Power

        function onMenuOpenChanged() {
            if (Power.menuOpen) {
                root.stage = "choose";
                root.pending = null;
            }
        }
    }

    // Locking is instantly reversible, so it is the one action that skips
    // confirm and runs straight from "choose" -- same rule Power.actions
    // itself already encodes with `confirm: false`.
    function choose(action) {
        if (action.confirm === false) {
            action.run();
            Power.menuOpen = false;
            return;
        }
        root.pending = action;
        root.stage = "confirm";
    }

    function decide(yes) {
        if (yes) {
            root.pending.run();
            Power.menuOpen = false;
        } else {
            root.pending = null;
            root.stage = "choose";
        }
    }

    // One square per action, in either stage: four from Power.actions while
    // choosing, two ("No"/"Yes") while confirming. Sized to fill the row it
    // is given rather than a fixed width, so both stages fill the same card
    // whether they are showing two tiles or four.
    component Tile: Rectangle {
        id: tile

        property string icon: ""
        property string label: ""
        // The one tile allowed to wear the critical red -- same rule as
        // SysPopup's kill button: the only thing on this card that is not
        // reversible gets the one colour that means that.
        property bool danger: false
        readonly property bool hovered: press.containsMouse

        signal picked()

        Layout.fillWidth: true
        implicitHeight: 58
        radius: Caelus.radiusCard
        color: tile.hovered ? Colors.surfaceHover : Colors.surfaceRaised
        border.width: Caelus.borderWidth
        border.color: Colors.popupBorder

        Behavior on color { ColorAnimation { duration: Motion.fast } }

        Column {
            anchors.centerIn: parent
            spacing: Caelus.spaceTight

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.icon
                color: tile.danger ? Colors.error : Colors.fgDim
                font.family: Caelus.symbolFamily
                font.pixelSize: 20
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.label
                color: Colors.fg
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
            }
        }

        MouseArea {
            id: press

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.picked()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Caelus.space

        Text {
            text: "power_settings_new"
            color: Colors.popupAccent
            font.family: Caelus.symbolFamily
            font.pixelSize: 16
        }

        Text {
            text: "Power"
            color: Colors.fg
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLead
        }

        Item { Layout.fillWidth: true }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Caelus.spaceSnug
        visible: root.stage === "choose"

        Repeater {
            model: Power.actions

            Tile {
                required property var modelData

                icon: modelData.icon
                label: modelData.label
                onPicked: root.choose(modelData)
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Caelus.spaceWide
        visible: root.stage === "confirm"

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.pending?.question ?? ""
            color: Colors.fg
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeBody
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.spaceSnug

            Tile {
                icon: "close"
                label: "No"
                onPicked: root.decide(false)
            }

            Tile {
                icon: "check"
                label: "Yes"
                danger: true
                onPicked: root.decide(true)
            }
        }
    }
}
