import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// A compact month grid for the dashboard, built from the same tokens and
// cell geometry CalendarPopup.qml's grid already uses (Colors.cal*,
// Caelus.radiusPill, the Monday-first 42-cell layout) so the two read as one
// calendar wherever either is seen -- but written fresh rather than by
// editing that file: CalendarPopup is a BarPopup itself (its grid is not a
// separate component, and the reminders/alarm fields below it are not part
// of what this card wants), and the contract's reuse rule for an agent's
// read-only files is to compose or rewrite against the same tokens, never
// to extract a component out of a file this round does not own.
ColumnLayout {
    id: root

    spacing: Caelus.spaceLoose

    property int monthOffset: 0

    readonly property date today: Time.now
    readonly property date firstShown: new Date(root.today.getFullYear(), root.today.getMonth() + root.monthOffset, 1)
    readonly property int shownYear: root.firstShown.getFullYear()
    readonly property int shownMonth: root.firstShown.getMonth()
    readonly property int lead: (root.firstShown.getDay() + 6) % 7

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Caelus.space

        Text {
            Layout.fillWidth: true
            text: Qt.formatDateTime(root.firstShown, "MMMM yyyy")
            color: Colors.calTitle
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeBody

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
                font.family: Caelus.symbolFamily
                font.pixelSize: Caelus.sizeLead

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
                Layout.preferredHeight: 16
                text: modelData
                color: Colors.calMeta
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Repeater {
            model: 42

            Item {
                id: cell

                required property int index

                readonly property date day: new Date(root.shownYear, root.shownMonth, 1 - root.lead + cell.index)
                readonly property bool outside: cell.day.getMonth() !== root.shownMonth
                readonly property bool isToday: root.sameDay(cell.day, root.today)

                Layout.fillWidth: true
                Layout.preferredHeight: 22

                Rectangle {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: Caelus.radiusPill
                    color: cell.isToday ? Colors.calToday : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.day.getDate()
                    color: cell.isToday ? Colors.calTodayFg
                        : cell.outside ? Colors.calOutside
                        : Colors.calBody
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                }
            }
        }
    }
}
