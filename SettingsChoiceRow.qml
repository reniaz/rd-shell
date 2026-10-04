import QtQuick
import QtQuick.Layouts
import qs.Config

// Kit component for the settings app: a label + equal-width segmented
// choice control, with a pill sliding behind the selected segment on
// Motion.spatialCurve -- the same curve the settings window's own nav-rail
// indicator slides on. One focus stop for the whole segmented track rather
// than one per segment: Left/Right cycle through `model` and apply
// immediately, the same "moving it is committing it" idiom
// SettingsSliderRow's own track keys use, so the keyboard story stays
// consistent between the two controls that both read an arrow key as "change
// the value", not "move a cursor".
//
// `caption` is shown verbatim when set; otherwise the row falls back to the
// current option's own `description`, so a page can either write a fixed
// caption or lean on whatever `model` already carries.
ColumnLayout {
    id: root

    property string icon: ""
    property string label: ""
    property string caption: ""
    property var model: []
    property string current: ""

    signal chosen(string id)

    Layout.fillWidth: true
    spacing: Caelus.spaceSnug

    opacity: root.enabled ? 1 : 0.4
    Behavior on opacity { NumberAnimation { duration: Motion.base } }

    readonly property int _currentIndex: {
        for (let i = 0; i < root.model.length; i++) {
            if (root.model[i].id === root.current) return i;
        }
        return -1;
    }

    readonly property string _description: root._currentIndex >= 0
        ? (root.model[root._currentIndex].description ?? "")
        : ""

    readonly property bool _hovered: headerHover.containsMouse

    function _select(index) {
        if (root.model.length === 0) return;
        const clamped = Math.max(0, Math.min(root.model.length - 1, index));
        root.chosen(root.model[clamped].id);
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: Math.max(52 * Caelus.uiScale, header.implicitHeight + Caelus.spaceWide * 2)

        Rectangle {
            anchors.fill: parent
            // ROUNDING RULE (user instruction): rows and their hover film
            // are square -- 0, never radiusCard.
            radius: 0
            color: root._hovered ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, Caelus.opacityHover) : "transparent"

            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        MouseArea {
            id: headerHover

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        RowLayout {
            id: header

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
                    id: captionText

                    Layout.fillWidth: true
                    readonly property string shown: root.caption !== "" ? root.caption : root._description
                    visible: captionText.shown !== ""
                    text: captionText.shown
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    Rectangle {
        id: seg

        Layout.fillWidth: true
        Layout.leftMargin: Caelus.spaceWide
        Layout.rightMargin: Caelus.spaceWide
        Layout.bottomMargin: Caelus.spaceSnug
        implicitHeight: 32 * Caelus.uiScale
        // ROUNDING RULE (user instruction): the segmented track and its
        // sliding pill are square -- 0, never radiusPill/height-2 pills. The
        // pill below reads `seg.radius` rather than a literal of its own, so
        // it can never drift from the track's own corner.
        radius: 0
        color: Colors.surfaceHover
        clip: true

        readonly property int count: root.model.length
        readonly property real cellW: seg.count > 0 ? seg.width / seg.count : 0

        Rectangle {
            visible: root._currentIndex >= 0
            width: seg.cellW
            height: seg.height
            radius: seg.radius
            color: Colors.popupAccent
            x: seg.cellW * Math.max(0, root._currentIndex)

            Behavior on x {
                NumberAnimation { duration: Motion.spatial; easing.type: Easing.Bezier; easing.bezierCurve: Motion.spatialCurve }
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Repeater {
                model: root.model

                Item {
                    id: cell

                    required property var modelData
                    required property int index

                    readonly property bool selected: cell.index === root._currentIndex

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.name ?? ""
                        color: cell.selected ? Colors.onAccent : Colors.fgDim
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeLabel

                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { segFocus.forceActiveFocus(); root._select(cell.index); }
                    }
                }
            }
        }

        FocusRing {
            anchors.fill: parent
            anchors.margins: -4
            radius: seg.radius
            show: segFocus.activeFocus
        }

        Item {
            id: segFocus

            anchors.fill: parent
            activeFocusOnTab: true

            Keys.onLeftPressed: root._select(root._currentIndex - 1)
            Keys.onRightPressed: root._select(root._currentIndex + 1)
        }
    }
}
