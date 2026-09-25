import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

RowLayout {
    id: root

    // Exposed for BarOverlays.qml: the clock pill's offset for the calendar
    // popup to anchor on, and its own open flag so the popup can close it.
    readonly property real clockAnchorX: clockPill.x + clockPill.width / 2
    property alias calendarOpen: clockPill.calendarOpen

    anchors.centerIn: parent
    spacing: Caelus.barSpacing

    Pill {
        id: clockPill

        pressed: clockArea.pressed

        property bool showReminder: false
        property bool calendarOpen: false

        icon: "schedule"
        // What is next to go off, in the place the date used to sit -- a
        // timer is set to be glanced at, and the date is a right-click away
        // in the month itself.
        label: clockPill.showReminder
            ? `${Time.time} | ${Reminders.next ? Format.countdown(Reminders.next.at, Reminders.now) : "no timer"}`
            : Time.time

        MouseArea {
            id: clockArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            // Left folds in what is next; right hangs the whole month under
            // it, which is where reminders are set.
            onClicked: mouse => mouse.button === Qt.RightButton
                ? clockPill.calendarOpen = !clockPill.calendarOpen
                : clockPill.showReminder = !clockPill.showReminder
        }
    }
}
