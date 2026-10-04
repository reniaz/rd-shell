import QtQuick
import QtQuick.Layouts
import qs.Config

// Kit component for the settings app (see the scratchpad contract this
// round builds against): the raised panel every settings row lives inside.
// `title` draws the same small section label SettingsPopup.qml's own
// "Accessibility" caption already uses -- a name sitting above the card's
// own border, not a header row inside it -- and is entirely optional: most
// cards on these pages carry just one, unlabelled.
//
// Consecutive rows get a 1px hairline between them (never around the whole
// stack, never under the last row). It is found by position rather than
// inserted by hand: a Repeater walks `inner.children` -- whatever the
// `content` alias actually appended -- and draws one line per gap, so any
// mix of SettingsToggleRow/SliderRow/ChoiceRow/ButtonRow can share a card
// without this file needing to know which ones it is holding, and a caption
// that wraps onto a second line still gets its hairline in the right place
// because the line is bound to the row's real height, not a guessed one.
ColumnLayout {
    id: root

    property string title: ""

    default property alias content: inner.data

    Layout.fillWidth: true
    spacing: Caelus.spaceTight

    Text {
        Layout.fillWidth: true
        visible: root.title !== ""
        text: root.title
        color: Colors.fgMuted
        font.family: Caelus.fontFamily
        font.pixelSize: Caelus.sizeLabel
    }

    Rectangle {
        id: body

        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + Caelus.spaceTight * 2
        // ROUNDING RULE (user instruction): cards are square -- 0, never
        // radiusPopover -- the one exception the rule carves out is small
        // controls (switch, buttons, chips), not the panels they sit in.
        radius: 0
        color: Colors.surfaceRaised

        ColumnLayout {
            id: inner

            anchors.fill: parent
            anchors.margins: Caelus.spaceTight
            spacing: 0
        }

        Repeater {
            model: Math.max(0, inner.children.length - 1)

            Rectangle {
                required property int index

                x: inner.x
                y: inner.y + inner.children[index].y + inner.children[index].height
                width: inner.width
                height: Math.max(1, Caelus.borderWidth)
                color: Colors.popupBorder
            }
        }
    }
}
