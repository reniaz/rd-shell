import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The dashboard's calendar: CalendarGrid.qml plus, below it, either the
// picked day's agenda or -- with nothing picked -- "Upcoming". Replaces
// DashCalendarGrid.qml (round 5): that file was the grid alone with no way
// to act on a day; this is CalendarPopup.qml's reminders/alarm half rebuilt
// around the grid instead of around a single always-"today" day, so nothing
// the popup could do is lost once the popup itself goes away.
//
// Every field/chip/button below reuses CalendarPopup.qml's own styling
// (Colors.cal*, Caelus.radiusCard) rather than inventing a second look for
// the same kind of control, so the dashboard and the (for now, still living)
// popup read as one calendar wherever either is seen.
ColumnLayout {
    id: root

    // Snug, not loose: this pane stacks a grid, an agenda/Upcoming list, a
    // compose row and two chip rows in the same 360px column DashMediaCard
    // and DashNotifications also live in (see NotchDashboard.qml) -- the
    // combined column must not push the dashboard card taller than the
    // screen, so every bit of vertical slack here is deliberately traded
    // for headroom the other cards need too.
    spacing: Caelus.spaceSnug

    // The exact 42 visible cells, recomputed whenever the grid pages -- and
    // only then; `_occ` below is what reruns on every reminder change.
    readonly property date _rangeStart: grid.rangeStart
    readonly property date _rangeEnd: grid.rangeEnd

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate();
    }

    // Every occurrence in the visible range, re-read whenever `Reminders.list`
    // changes -- `occurrences()` itself has no property of its own to bind
    // to, so this reads `list` directly (per the contract) purely to be a
    // binding dependency, same reasoning CalendarPopup's own Repeater leaned
    // on `Reminders.list` for.
    readonly property var _occ: {
        Reminders.list;
        return Reminders.occurrences(root._rangeStart.getTime(), root._rangeEnd.getTime());
    }

    // The grid's dot colours: all-day in `calMeta` (quieter -- nothing to
    // count down to), a repeating occurrence in `popupAccent` (the same
    // accent the segmented settings controls use for "this one is chosen"),
    // a plain timed one-off in `calAlarm`. Three existing tokens, no new
    // colour literal.
    function marksFor(date) {
        return root._occ
            .filter(o => root.sameDay(new Date(o.at), date))
            .map(o => o.allDay ? Colors.calMeta : o.repeat !== "none" ? Colors.popupAccent : Colors.calAlarm);
    }

    function occForDay(date) {
        return root._occ.filter(o => root.sameDay(new Date(o.at), date)).sort((a, b) => a.at - b.at);
    }

    readonly property var timeParts: composeTime.text.match(/^(\d{1,2}):([0-5]\d)$/)
    readonly property bool timeValid: !!timeParts && parseInt(timeParts[1]) <= 23
    property string composeRepeat: "none"
    property bool composeAllDay: false
    // A day already over is refused outright rather than rolled forward: the
    // grid pages freely into past months, and a reminder stored there would
    // fire on the very next tick of Reminders' ticker -- an instant alarm for
    // a date the user was only browsing. Today itself stays allowed (a time
    // already gone today rolls to tomorrow in composeAdd()).
    readonly property bool pickedPast: !!grid.picked
        && new Date(grid.picked.getFullYear(), grid.picked.getMonth(), grid.picked.getDate())
           < new Date(grid.today.getFullYear(), grid.today.getMonth(), grid.today.getDate())
    readonly property bool canAdd: !root.pickedPast && (root.composeAllDay || root.timeValid)

    function dayLabel(date) {
        return grid.sameDay(date, grid.today) ? "today"
            : grid.sameDay(date, new Date(grid.today.getFullYear(), grid.today.getMonth(), grid.today.getDate() + 1)) ? "tomorrow"
            : Qt.formatDateTime(date, "ddd d MMM");
    }

    function composeAdd() {
        const text = composeText.text.trim();
        const day = grid.picked ?? grid.today;
        if (!root.canAdd) return;

        if (root.composeAllDay) {
            Reminders.add(new Date(day.getFullYear(), day.getMonth(), day.getDate()).getTime(), text, { allDay: true, repeat: root.composeRepeat });
        } else {
            if (!root.timeValid) return;
            const at = new Date(day.getFullYear(), day.getMonth(), day.getDate(),
                                parseInt(root.timeParts[1]), parseInt(root.timeParts[2]), 0, 0);
            // A time already gone today rolls to tomorrow, same rule
            // CalendarPopup.qml's own addAlarm() used.
            if (at.getTime() <= Date.now() && grid.sameDay(day, grid.today))
                at.setDate(at.getDate() + 1);
            Reminders.add(at.getTime(), text, { allDay: false, repeat: root.composeRepeat });
        }
        composeText.text = "";
        composeTime.text = "";
    }

    // Empty text is deliberately allowed here and in composeAdd(): an
    // unlabelled 5-minute timer is a kitchen timer, and Reminders.add names it
    // "Reminder" -- the same as the v1 popup did.
    function addTimer(minutes) {
        Reminders.addIn(minutes, composeText.text.trim());
        composeText.text = "";
    }

    CalendarGrid {
        id: grid

        Layout.fillWidth: true
        marks: root.marksFor
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Colors.popupBorder
    }

    // The agenda (a day picked) or Upcoming (nothing picked) -- same header
    // row either way, just what follows it differs.
    RowLayout {
        Layout.fillWidth: true
        spacing: Caelus.space

        Text {
            text: "event"
            color: Colors.calIcon
            font.family: Caelus.symbolFamily
            font.pixelSize: Caelus.sizeLead
        }

        Text {
            Layout.fillWidth: true
            text: grid.picked !== null ? root.dayLabel(grid.picked) : "Upcoming"
            color: Colors.calTitle
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeBody
        }

        // A second way back to Upcoming besides re-clicking the picked cell
        // -- discoverable without having to already know the grid's own
        // toggle-click trick.
        Text {
            visible: grid.picked !== null
            text: "Upcoming"
            color: upcomingHover.containsMouse ? Colors.calTitle : Colors.calMeta
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel

            MouseArea {
                id: upcomingHover

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: grid.picked = null
            }
        }
    }

    // One day's agenda: every occurrence on it, inline-editable.
    ColumnLayout {
        Layout.fillWidth: true
        visible: grid.picked !== null
        spacing: Caelus.spaceSnug

        Text {
            Layout.fillWidth: true
            visible: grid.picked !== null && root.occForDay(grid.picked).length === 0
            text: "Nothing on this day"
            color: Colors.calMeta
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel
        }

        Repeater {
            model: grid.picked !== null ? root.occForDay(grid.picked) : []

            AgendaRow { Layout.fillWidth: true }
        }
    }

    // Upcoming: the next few reminders, soonest first -- CalendarPopup.qml's
    // own pending list, unchanged in spirit (countdown + cancel), just moved
    // here for when no day is picked.
    ColumnLayout {
        Layout.fillWidth: true
        visible: grid.picked === null
        spacing: Caelus.spaceSnug

        Text {
            Layout.fillWidth: true
            visible: Reminders.count === 0
            text: "Nothing pending"
            color: Colors.calMeta
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel
        }

        Repeater {
            // Capped to a handful -- a glance, not the whole list; the full
            // list is always reachable by paging to the day it's on.
            model: Reminders.list.slice(0, 4)

            UpcomingRow { Layout.fillWidth: true }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Colors.popupBorder
    }

    // Compose row: text, time (hidden behind the all-day toggle), repeat,
    // all-day, add.
    RowLayout {
        Layout.fillWidth: true
        spacing: Caelus.spaceSnug

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 28
            radius: Caelus.radiusCard
            color: Colors.calField
            border.width: 1
            border.color: composeText.activeFocus ? Colors.calAlarm : Colors.calFieldBorder

            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

            TextInput {
                id: composeText

                anchors.fill: parent
                anchors.leftMargin: Caelus.space
                anchors.rightMargin: Caelus.space
                verticalAlignment: TextInput.AlignVCenter
                color: Colors.calTitle
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
                selectByMouse: true
                onAccepted: root.composeAdd()
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Caelus.space
                anchors.verticalCenter: parent.verticalCenter
                text: "remind me to…"
                visible: composeText.text === ""
                color: Colors.calMeta
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
            }
        }

        Rectangle {
            Layout.preferredWidth: 54
            implicitHeight: 28
            radius: Caelus.radiusCard
            visible: !root.composeAllDay
            color: Colors.calField
            border.width: 1
            border.color: composeTime.activeFocus ? Colors.calAlarm : Colors.calFieldBorder

            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

            TextInput {
                id: composeTime

                anchors.fill: parent
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                color: root.timeValid || composeTime.text === "" ? Colors.calTitle : Colors.error
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
                maximumLength: 5
                selectByMouse: true
                onAccepted: root.composeAdd()
            }

            Text {
                anchors.centerIn: parent
                text: "HH:MM"
                visible: composeTime.text === ""
                color: Colors.calMeta
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
            }
        }

        Rectangle {
            implicitWidth: 30
            implicitHeight: 28
            radius: Caelus.radiusCard
            color: addHover.containsMouse && root.canAdd ? Colors.calFieldBorder : Colors.calField
            border.width: 1
            border.color: Colors.calFieldBorder

            Text {
                anchors.centerIn: parent
                text: "add_alarm"
                color: root.canAdd ? Colors.calAlarm : Colors.calMeta
                font.family: Caelus.symbolFamily
                font.pixelSize: 16
            }

            MouseArea {
                id: addHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.canAdd ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.composeAdd()
            }
        }
    }

    // Repeat chips + the all-day toggle, same row -- both are compose-time
    // options for the reminder about to be added, not reminders of their
    // own.
    RowLayout {
        Layout.fillWidth: true
        spacing: Caelus.spaceSnug

        Repeater {
            model: Reminders.repeats

            Rectangle {
                id: repeatChip

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 22
                radius: Caelus.radiusCard
                color: root.composeRepeat === repeatChip.modelData.id ? Colors.popupAccent
                    : repeatHover.containsMouse ? Colors.calFieldBorder : Colors.calField
                border.width: 1
                border.color: Colors.calFieldBorder

                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Text {
                    anchors.centerIn: parent
                    text: repeatChip.modelData.name
                    color: root.composeRepeat === repeatChip.modelData.id ? Colors.onAccent : Colors.calBody
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel * 0.9
                }

                MouseArea {
                    id: repeatHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.composeRepeat = repeatChip.modelData.id
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 54
            implicitHeight: 22
            radius: Caelus.radiusCard
            color: root.composeAllDay ? Colors.popupAccent : (allDayHover.containsMouse ? Colors.calFieldBorder : Colors.calField)
            border.width: 1
            border.color: Colors.calFieldBorder

            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Text {
                anchors.centerIn: parent
                text: "all day"
                color: root.composeAllDay ? Colors.onAccent : Colors.calBody
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel * 0.9
            }

            MouseArea {
                id: allDayHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.composeAllDay = !root.composeAllDay
            }
        }
    }

    // The other half: no time of day, just a distance from now -- unchanged
    // from CalendarPopup.qml except for dropping the 60-minute chip, which
    // the contract's UI decision for this pane only asks for 5/15/30.
    RowLayout {
        Layout.fillWidth: true
        spacing: Caelus.spaceSnug

        Text {
            text: "timer"
            color: Colors.calMeta
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel
        }

        Repeater {
            model: [5, 15, 30]

            Rectangle {
                id: timerChip

                required property int modelData

                Layout.fillWidth: true
                implicitHeight: 24
                radius: Caelus.radiusCard
                color: timerHover.containsMouse ? Colors.calFieldBorder : Colors.calField
                border.width: 1
                border.color: Colors.calFieldBorder

                Text {
                    anchors.centerIn: parent
                    text: timerChip.modelData + "m"
                    color: Colors.calBody
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                }

                MouseArea {
                    id: timerHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addTimer(timerChip.modelData)
                }
            }
        }
    }

    // One agenda row: time/all-day, text (inline-editable), a repeat chip
    // that cycles on click, snooze, delete. Compact on purpose -- this is a
    // day's worth of reminders in a 360px column, not a full editor.
    component AgendaRow: RowLayout {
        id: agendaRow

        required property var modelData

        spacing: Caelus.spaceSnug

        Text {
            Layout.preferredWidth: 40
            text: agendaRow.modelData.allDay ? "all day" : Qt.formatDateTime(new Date(agendaRow.modelData.at), "HH:mm")
            color: Colors.calAlarm
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel * 0.9
        }

        TextInput {
            id: textEdit

            Layout.fillWidth: true
            text: agendaRow.modelData.text
            color: Colors.calBody
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel
            selectByMouse: true
            onAccepted: { Reminders.update(agendaRow.modelData.id, { text: textEdit.text }); textEdit.focus = false; }
            onActiveFocusChanged: if (!textEdit.activeFocus && textEdit.text !== agendaRow.modelData.text) Reminders.update(agendaRow.modelData.id, { text: textEdit.text });
        }

        // Cycles to the next repeat option on click -- a full segmented
        // choice row (SettingsChoiceRow.qml's own look) would not fit this
        // row's width; cycling is the compact equivalent of the same
        // control.
        Text {
            text: (Reminders.repeats.find(r => r.id === agendaRow.modelData.repeat) ?? Reminders.repeats[0]).name
            color: repeatCycleHover.containsMouse ? Colors.calTitle : Colors.calMeta
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel * 0.9

            MouseArea {
                id: repeatCycleHover

                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const ids = Reminders.repeats.map(r => r.id);
                    const next = ids[(ids.indexOf(agendaRow.modelData.repeat) + 1) % ids.length];
                    Reminders.update(agendaRow.modelData.id, { repeat: next });
                }
            }
        }

        Text {
            text: "snooze"
            color: snoozeHover.containsMouse ? Colors.calTitle : Colors.calMeta
            font.family: Caelus.symbolFamily
            font.pixelSize: 14

            MouseArea {
                id: snoozeHover

                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Reminders.snooze(agendaRow.modelData.id, 10)
            }
        }

        Text {
            text: "close"
            color: deleteHover.containsMouse ? Colors.error : Colors.calMeta
            font.family: Caelus.symbolFamily
            font.pixelSize: 14

            MouseArea {
                id: deleteHover

                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Reminders.remove(agendaRow.modelData.id)
            }
        }
    }

    // Upcoming's row: text, countdown, snooze, cancel -- CalendarPopup.qml's
    // own pending-list row, plus the snooze action its card never had
    // because it had no notification-action wiring to snooze yet.
    component UpcomingRow: RowLayout {
        id: upcomingRow

        required property var modelData

        spacing: Caelus.spaceSnug

        Text {
            Layout.fillWidth: true
            text: upcomingRow.modelData.text
            color: Colors.calBody
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel
            elide: Text.ElideRight
        }

        Text {
            text: Format.countdown(upcomingRow.modelData.at, Reminders.now)
            color: Colors.calAlarm
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel
        }

        Text {
            text: "snooze"
            color: upcomingSnoozeHover.containsMouse ? Colors.calTitle : Colors.calMeta
            font.family: Caelus.symbolFamily
            font.pixelSize: 14

            MouseArea {
                id: upcomingSnoozeHover

                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Reminders.snooze(upcomingRow.modelData.id, 10)
            }
        }

        Text {
            text: "close"
            color: upcomingCancelHover.containsMouse ? Colors.error : Colors.calMeta
            font.family: Caelus.symbolFamily
            font.pixelSize: 14

            MouseArea {
                id: upcomingCancelHover

                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Reminders.remove(upcomingRow.modelData.id)
            }
        }
    }
}
