import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The month behind the bar's clock. The card, its notch and the click-outside
// dismissal all belong to BarPopup; what is left here is the grid.
BarPopup {
    id: root

    namespace: "qs-calendar"
    popupWidth: 268
    popupHeight: body.implicitHeight + 28

    // Which month is on screen, as a distance from the one we are in. Lives on
    // the popup and not on a service: paging back to March is a question you
    // asked this card, and closing it is the answer being thrown away.
    property int monthOffset: 0

    // Today is read from the same clock the pill prints, so the highlighted cell
    // rolls over at midnight without anything here having to watch for it.
    readonly property date today: Time.now
    readonly property date firstShown: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
    readonly property int shownYear: firstShown.getFullYear()
    readonly property int shownMonth: firstShown.getMonth()

    // How many trailing days of the previous month the first row has to show.
    // JavaScript counts weeks from Sunday and this grid starts on Monday, hence
    // the rotation.
    readonly property int lead: (firstShown.getDay() + 6) % 7

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "calendar_month"
                color: Colors.calIcon
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
            }

            // The month is also the way back to this one: paging four months out
            // and having no way home but the arrows is the whole complaint about
            // every calendar that does this.
            Text {
                Layout.fillWidth: true
                text: Qt.formatDateTime(root.firstShown, "MMMM yyyy")
                color: Colors.calTitle
                font.family: "caelusevka"
                font.pixelSize: 15

                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.monthOffset === 0 ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: root.monthOffset = 0
                }
            }

            Repeater {
                model: [
                    { glyph: "chevron_left", step: -1 },
                    { glyph: "chevron_right", step: 1 }
                ]

                Text {
                    id: nav

                    required property var modelData

                    text: nav.modelData.glyph
                    color: navHover.containsMouse ? Colors.calTitle : Colors.calMeta
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18

                    MouseArea {
                        id: navHover

                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.monthOffset += nav.modelData.step
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 0
            rowSpacing: 1

            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                Text {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    text: modelData
                    color: Colors.calMeta
                    font.family: "caelusevka"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Six rows always, so the card keeps one height whichever month is
            // shown and paging through the year does not make it breathe.
            Repeater {
                model: 42

                Item {
                    id: cell

                    required property int index

                    readonly property date day: new Date(root.shownYear, root.shownMonth, 1 - root.lead + cell.index)
                    readonly property bool outside: cell.day.getMonth() !== root.shownMonth
                    readonly property bool isToday: cell.day.getFullYear() === root.today.getFullYear()
                        && cell.day.getMonth() === root.today.getMonth()
                        && cell.day.getDate() === root.today.getDate()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    Rectangle {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: height / 2
                        color: cell.isToday ? Colors.calToday : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.day.getDate()
                        color: cell.isToday ? Colors.calTodayFg
                            : cell.outside ? Colors.calOutside
                            : Colors.calBody
                        font.family: "caelusevka"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
