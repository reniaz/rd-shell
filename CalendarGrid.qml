import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The 42-cell month grid, lifted out of CalendarPopup.qml (round 5) so the
// dashboard's calendar pane and the bar's own popup can both build on it
// without one copying the other's cell geometry by hand. Same tokens
// (Colors.cal*, Caelus.radiusPill, the Monday-first 42-cell layout) as the
// popup this was lifted from, plus three things the popup never needed: a
// `marks` hook for the reminder dots, a keyboard story (the popup only ever
// took mouse clicks), and `Settings.weekStart`/`Settings.weekNumbers`.
//
// A FocusScope, not a plain Item: BarPopup's own card grabs `focus: true` on
// completion (see BarPopup.qml), and without this grid asking for focus too
// nothing below it would ever see an arrow key. Escape is unaffected either
// way -- NotchDashboard.qml closes on a `Shortcut`, which fires from window
// focus, not from whichever Item currently holds active focus inside it.
FocusScope {
    id: root

    // Today is read from the same clock the pill prints, so the highlighted
    // cell rolls over at midnight without anything here having to watch for
    // one.
    readonly property date today: Time.now

    // Which month is on screen, as a distance from the one we are in -- same
    // idea CalendarPopup.qml's own monthOffset used, kept on this grid and
    // not on a service for the same reason: paging four months out and then
    // closing the dashboard is a question this card asked, and the answer is
    // thrown away with it.
    property int monthOffset: 0

    // The day an agenda is shown for, or null for none -- DashCalendarPane.qml
    // reads this to decide between a day's agenda and "Upcoming" (deliberate,
    // round 5: CalendarPopup always had *some* day picked, defaulting to
    // today; the dashboard pane starts with nothing picked on purpose, so
    // opening it reads as a glance at what's coming rather than always
    // landing on today's -- usually empty -- agenda). `var`, not `date`:
    // QML's `date` type has no null, and "nothing picked" has to be a real,
    // distinguishable state here, not just today-by-default.
    //
    // Plain property, not a formal two-way binding -- DashCalendarPane.qml
    // both reads it (to choose agenda vs. Upcoming) and writes it (an
    // "Upcoming" link clears it back to null), and this grid writes it too
    // (a click, an arrow key, T). Whichever side wrote it last wins, same as
    // any other QML property; nothing here needs to be told which side that
    // was.
    property var picked: null

    // The dot colours under each date, supplied by the caller -- this grid
    // has no idea what a reminder is. Default returns nothing, so a bare
    // CalendarGrid with no `marks` set still renders the plain month it
    // always has.
    property var marks: function (date) { return []; }

    // How many trailing days of the previous month the first row has to
    // show. JavaScript counts weeks from Sunday; rotated by `weekStartIdx`
    // so the lead works out the same way whichever day `Settings.weekStart`
    // starts the row on.
    readonly property int weekStartIdx: Settings.weekStart === "sunday" ? 0 : 1
    readonly property date firstShown: new Date(root.today.getFullYear(), root.today.getMonth() + root.monthOffset, 1)
    readonly property int shownYear: root.firstShown.getFullYear()
    readonly property int shownMonth: root.firstShown.getMonth()
    readonly property int lead: (root.firstShown.getDay() - root.weekStartIdx + 7) % 7

    // The exact range the 42 visible cells cover, in epoch ms -- exposed so a
    // caller's `marks` function (and DashCalendarPane's own occurrences()
    // lookup) can ask Reminders for precisely what's on screen rather than
    // guessing a month's worth of bounds that wouldn't cover the lead-in/
    // trailing days from the neighbouring months.
    readonly property date rangeStart: new Date(root.shownYear, root.shownMonth, 1 - root.lead)
    readonly property date rangeEnd: new Date(root.shownYear, root.shownMonth, 1 - root.lead + 42)

    // Compact on purpose: this grid now shares the dashboard column with an
    // agenda, a compose row and repeat/timer chips below it (see
    // DashCalendarPane.qml), and the whole pane must not push the dashboard
    // taller than the screen -- CalendarPopup's own 28px cell had nothing
    // below it competing for height.
    readonly property int cellH: 30

    function sameDay(a, b) {
        if (!a || !b) return false;
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate();
    }

    // ISO-8601 week numbering (Monday-based) regardless of `weekStart` --
    // the number printed beside a Sunday-first row is the same number a
    // Monday-first calendar would print for it. Deliberate: week numbers are
    // a convention of their own, and a week-number column that disagreed
    // with every other calendar on the wall would be worse than one that
    // just always counts the same way.
    function isoWeek(d) {
        const date = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        const day = (date.getDay() + 6) % 7;
        date.setDate(date.getDate() - day + 3);
        const firstThursday = new Date(date.getFullYear(), 0, 4);
        const thursdayDay = (firstThursday.getDay() + 6) % 7;
        firstThursday.setDate(firstThursday.getDate() - thursdayDay + 3);
        return 1 + Math.round((date.getTime() - firstThursday.getTime()) / (7 * 86400000));
    }

    function weekdayLabels() {
        const mon = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];
        return root.weekStartIdx === 0 ? ["Su"].concat(mon.slice(0, 6)) : mon;
    }

    // Moves `picked` by whole days, carrying the shown month along with it --
    // an arrow key that walked `picked` out of the visible 42 cells without
    // paging the grid to follow it would be worse than not moving at all.
    function moveDay(delta) {
        const base = root.picked ?? root.today;
        const next = new Date(base.getFullYear(), base.getMonth(), base.getDate() + delta);
        root.picked = next;
        root.monthOffset = (next.getFullYear() - root.today.getFullYear()) * 12
            + (next.getMonth() - root.today.getMonth());
    }

    function goToday() {
        root.monthOffset = 0;
        root.picked = root.today;
    }

    implicitHeight: body.implicitHeight

    // Takes keyboard focus the moment it exists, so paging works the instant
    // the dashboard opens with no click needed first -- clicking into a
    // compose field elsewhere steals it back (TextInput grabs active focus
    // on a mouse press on its own), and clicking back on the grid itself
    // (see the MouseArea below) is what returns it.
    Component.onCompleted: root.forceActiveFocus()

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left: root.moveDay(-1); break;
        case Qt.Key_Right: root.moveDay(1); break;
        case Qt.Key_Up: root.moveDay(-7); break;
        case Qt.Key_Down: root.moveDay(7); break;
        case Qt.Key_PageUp: root.monthOffset -= 1; break;
        case Qt.Key_PageDown: root.monthOffset += 1; break;
        case Qt.Key_T: root.goToday(); break;
        default: return;
        }
        event.accepted = true;
    }

    MouseArea {
        id: wheelArea

        anchors.fill: parent
        onWheel: wheel => {
            root.forceActiveFocus();
            root.monthOffset += wheel.angleDelta.y > 0 ? -1 : 1;
        }
        // Clicks on the header/weekday row/gaps between cells still return
        // focus here; the day cells below carry their own MouseArea that
        // also grabs focus, declared after this one so they see the click
        // first.
        onClicked: root.forceActiveFocus()
    }

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Caelus.spaceSnug

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
                    onClicked: { root.forceActiveFocus(); root.monthOffset = 0; }
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
                        onClicked: { root.forceActiveFocus(); root.monthOffset += nav.modelData.step; }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Item {
                visible: Settings.weekNumbers
                Layout.preferredWidth: 16
                Layout.preferredHeight: 18
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 0
                rowSpacing: 0

                Repeater {
                    model: root.weekdayLabels()

                    Text {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        text: modelData
                        color: Colors.calMeta
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeLabel
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            // One label per row, aligned to the same `cellH` the day cells
            // use below -- a plain Column of its own rather than an eighth
            // GridLayout column, since the Repeater producing the 42 day
            // cells works in a single flat run and has no row boundary of
            // its own to hang an extra column off every seventh item.
            ColumnLayout {
                visible: Settings.weekNumbers
                Layout.preferredWidth: 16
                spacing: 0

                Repeater {
                    model: 6

                    Text {
                        required property int index

                        Layout.preferredWidth: 16
                        Layout.preferredHeight: root.cellH
                        text: "W" + root.isoWeek(new Date(root.shownYear, root.shownMonth, 1 - root.lead + index * 7))
                        color: Colors.calMeta
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeLabel * 0.85
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 0
                rowSpacing: 0

                // Six rows always, so the card keeps one height whichever
                // month is shown and paging through the year does not make
                // it breathe.
                Repeater {
                    model: 42

                    Item {
                        id: cell

                        required property int index

                        readonly property date day: new Date(root.shownYear, root.shownMonth, 1 - root.lead + cell.index)
                        readonly property bool outside: cell.day.getMonth() !== root.shownMonth
                        readonly property bool isToday: root.sameDay(cell.day, root.today)
                        readonly property bool isPicked: root.sameDay(cell.day, root.picked)
                        readonly property var dots: root.marks(cell.day)

                        Layout.fillWidth: true
                        Layout.preferredHeight: root.cellH

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Item {
                                width: 20
                                height: 20
                                anchors.horizontalCenter: parent.horizontalCenter

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    radius: Caelus.radiusPill
                                    color: cell.isToday ? Colors.calToday : "transparent"
                                    // A ring rather than a second disc: the
                                    // filled one means today, and two of them
                                    // would be one too many.
                                    border.width: cell.isPicked && !cell.isToday ? 1 : 0
                                    border.color: Colors.calAlarm
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

                            // Up to 3 dots, then "+N" for the rest -- a fixed-
                            // height row even with zero marks, so a bare
                            // month and a busy one keep identical row
                            // heights instead of the grid breathing between
                            // weeks.
                            Row {
                                height: 6
                                spacing: 2
                                anchors.horizontalCenter: parent.horizontalCenter

                                Repeater {
                                    model: Math.min(cell.dots.length, 3)

                                    Rectangle {
                                        required property int index

                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: cell.dots[index]
                                    }
                                }

                                Text {
                                    visible: cell.dots.length > 3
                                    text: "+" + (cell.dots.length - 3)
                                    color: Colors.calMeta
                                    font.family: Caelus.fontFamily
                                    font.pixelSize: Caelus.sizeLabel * 0.8
                                }
                            }
                        }

                        // Picking a day is the whole of what a click on the
                        // grid does. Clicking the day already picked clears
                        // it instead -- the only way back to "Upcoming"
                        // without reaching for the pane's own link
                        // (deliberate, round 5: a toggle costs nothing extra
                        // to wire and means the grid alone is enough to get
                        // back).
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.forceActiveFocus();
                                root.picked = cell.isPicked ? null : new Date(cell.day);
                            }
                        }
                    }
                }
            }
        }

        // One-line key legend -- the grid takes real keyboard input now
        // (CalendarPopup.qml never did), so it says so once rather than
        // leaving the keys to be discovered by accident.
        Text {
            Layout.fillWidth: true
            Layout.topMargin: Caelus.spaceTight
            text: "←↑↓→ day · PgUp/PgDn month · wheel month · T today"
            color: Colors.calMeta
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeLabel * 0.85
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
