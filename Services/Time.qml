pragma Singleton
import Quickshell

Singleton {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property date now: clock.date
    readonly property string time: Qt.formatDateTime(clock.date, "HH:mm")
    readonly property string date: Qt.formatDateTime(clock.date, "ddd d MMM")
    readonly property int hours: clock.hours
    readonly property int minutes: clock.minutes
}
