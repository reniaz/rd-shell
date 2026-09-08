import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The month behind the bar's clock, and the reminders set from it. The card, its
// notch and the click-outside dismissal all belong to BarPopup; what is left
// here is the grid and the two ways to be reminded of something -- a timer some
// minutes out, or an alarm at a time on a day of the grid.
BarPopup {
    id: root

    namespace: "qs-calendar"
    popupWidth: 296
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

    // The day an alarm would land on. A binding until a cell is clicked, so it
    // follows the date over midnight for as long as nobody has picked a day.
    property date picked: root.today

    // How many trailing days of the previous month the first row has to show.
    // JavaScript counts weeks from Sunday and this grid starts on Monday, hence
    // the rotation.
    readonly property int lead: (firstShown.getDay() + 6) % 7

    // What is in the two fields, published here rather than read out of them:
    // the alarm is assembled from the card's own state, and a field is only how
    // that state is typed.
    property alias draftText: alarmText.text
    property alias draftTime: alarmTime.text

    readonly property var timeParts: root.draftTime.match(/^(\d{1,2}):([0-5]\d)$/)
    readonly property bool timeValid: !!timeParts && parseInt(timeParts[1]) <= 23

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate();
    }

    function addAlarm() {
        if (!root.timeValid)
            return;

        const at = new Date(root.picked.getFullYear(), root.picked.getMonth(), root.picked.getDate(),
                            parseInt(root.timeParts[1]), parseInt(root.timeParts[2]), 0, 0);
        // A time already gone on the day you picked means the next one round:
        // 07:30 typed at eleven at night is tomorrow morning, not this morning.
        // setDate rather than adding a day in milliseconds, so the hour survives
        // a clock change overnight.
        if (at.getTime() <= Date.now() && root.sameDay(root.picked, root.today))
            at.setDate(at.getDate() + 1);

        Reminders.add(at.getTime(), root.draftText.trim());
        root.draftText = "";
        root.draftTime = "";
    }

    function addTimer(minutes) {
        Reminders.addIn(minutes, root.draftText.trim());
        root.draftText = "";
    }

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
                    readonly property bool isToday: root.sameDay(cell.day, root.today)
                    readonly property bool isPicked: root.sameDay(cell.day, root.picked)

                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    Rectangle {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: height / 2
                        color: cell.isToday ? Colors.calToday : "transparent"
                        // A ring rather than a second disc: the filled one means
                        // today, and two of them would be one too many.
                        border.width: cell.isPicked && !cell.isToday ? 1 : 0
                        border.color: Colors.calAlarm
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

                    // Picking a day is the whole of what a click on the grid
                    // does: it is the date the alarm field below writes to.
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked = cell.day
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "alarm"
                color: Colors.calAlarm
                font.family: "Material Symbols Rounded"
                font.pixelSize: 15
            }

            Text {
                Layout.fillWidth: true
                text: "Reminders"
                color: Colors.calTitle
                font.family: "caelusevka"
                font.pixelSize: 13
            }

            // Which day the alarm field means. Without it the picked cell up in
            // the grid is the only sign, and a time typed here would otherwise
            // be read as today's.
            Text {
                text: root.sameDay(root.picked, root.today) ? "today"
                    : Qt.formatDateTime(root.picked, "ddd d MMM")
                color: Colors.calMeta
                font.family: "caelusevka"
                font.pixelSize: 12
            }
        }

        // Everything pending, soonest first. Nothing is drawn when nothing is
        // set -- an empty list would say nothing the fields below do not.
        Repeater {
            model: Reminders.list

            RowLayout {
                id: pending

                required property var modelData

                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: pending.modelData.text
                    color: Colors.calBody
                    font.family: "caelusevka"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    text: Format.countdown(pending.modelData.at, Reminders.now)
                    color: Colors.calAlarm
                    font.family: "caelusevka"
                    font.pixelSize: 12
                }

                Text {
                    id: cancel

                    text: "close"
                    color: cancelHover.containsMouse ? Colors.error : Colors.calMeta
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 14

                    MouseArea {
                        id: cancelHover

                        anchors.fill: parent
                        anchors.margins: -3
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Reminders.remove(pending.modelData.id)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                radius: 8
                color: Colors.calField
                border.width: 1
                border.color: alarmText.activeFocus ? Colors.calAlarm : Colors.calFieldBorder

                Behavior on border.color { ColorAnimation { duration: 120 } }

                TextInput {
                    id: alarmText

                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.calTitle
                    font.family: "caelusevka"
                    font.pixelSize: 12
                    selectByMouse: true
                    // Enter from either field sets the alarm, so a reminder can
                    // be typed and set without the mouse coming back.
                    onAccepted: root.addAlarm()
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "remind me to…"
                    visible: alarmText.text === ""
                    color: Colors.calMeta
                    font.family: "caelusevka"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                Layout.preferredWidth: 54
                implicitHeight: 28
                radius: 8
                color: Colors.calField
                border.width: 1
                border.color: alarmTime.activeFocus ? Colors.calAlarm : Colors.calFieldBorder

                Behavior on border.color { ColorAnimation { duration: 120 } }

                TextInput {
                    id: alarmTime

                    anchors.fill: parent
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.timeValid || alarmTime.text === "" ? Colors.calTitle : Colors.error
                    font.family: "caelusevka"
                    font.pixelSize: 12
                    maximumLength: 5
                    selectByMouse: true
                    onAccepted: root.addAlarm()
                }

                Text {
                    anchors.centerIn: parent
                    text: "HH:MM"
                    visible: alarmTime.text === ""
                    color: Colors.calMeta
                    font.family: "caelusevka"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                implicitWidth: 30
                implicitHeight: 28
                radius: 8
                color: addHover.containsMouse && root.timeValid ? Colors.calFieldBorder : Colors.calField
                border.width: 1
                border.color: Colors.calFieldBorder

                Text {
                    anchors.centerIn: parent
                    text: "add_alarm"
                    // Dimmed rather than hidden while the time is unusable: the
                    // button vanishing under the cursor is worse than it saying
                    // no.
                    color: root.timeValid ? Colors.calAlarm : Colors.calMeta
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                }

                MouseArea {
                    id: addHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.timeValid ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.addAlarm()
                }
            }
        }

        // The other half: no time of day, just a distance from now. Same text
        // field, so a label typed above is carried into whichever of the two is
        // clicked.
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "timer"
                color: Colors.calMeta
                font.family: "caelusevka"
                font.pixelSize: 12
            }

            Repeater {
                model: [5, 15, 30, 60]

                Rectangle {
                    id: chip

                    required property int modelData

                    Layout.fillWidth: true
                    implicitHeight: 24
                    radius: 8
                    color: chipHover.containsMouse ? Colors.calFieldBorder : Colors.calField
                    border.width: 1
                    border.color: Colors.calFieldBorder

                    Text {
                        anchors.centerIn: parent
                        text: chip.modelData < 60 ? chip.modelData + "m" : (chip.modelData / 60) + "h"
                        color: Colors.calBody
                        font.family: "caelusevka"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: chipHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addTimer(chip.modelData)
                    }
                }
            }
        }
    }
}
