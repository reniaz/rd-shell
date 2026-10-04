pragma Singleton
import Quickshell

// Read by the bar clock pill (BarCenter.qml), the desktop clock
// (DesktopClock.qml) and the lock screen (LockSurface.qml) -- one singleton,
// so all three always agree on what time it is and how it's written. That's
// also why `time`'s format is a Settings.qml property (clockFormat/
// clockSeconds) rather than something a page sets per-surface: splitting it
// would let the bar read 24h while the lock screen reads 12h, which would
// look like a bug. No typeof guard on Settings here, unlike Config/Caelus.qml
// -- this file lives in the same qs.Services directory Settings.qml does,
// where every other service (Services/BarStyles.qml, for one) already reads
// Settings straight, with no import needed and no "before it exists in the
// tree" case to guard against.
Singleton {
    id: root

    SystemClock {
        id: clock
        // Minutes by default -- same as this file always ran. Only drops to
        // a once-a-second tick while Settings.clockSeconds is actually on,
        // so a machine that never touches that setting gets no extra wakeup
        // it didn't have before.
        precision: Settings.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property date now: clock.date

    // "24h" (default) reproduces today's hard-coded "HH:mm" exactly;
    // "12h" swaps in a 12-hour hour plus an AM/PM suffix. clockSeconds
    // inserts ":ss" either way. Settings.qml's own JsonAdapter defaults
    // ("24h", false) are exactly these, so a fresh settings.json renders
    // pixel-identical to before either setting existed.
    readonly property string _pattern: Settings.clockFormat === "12h"
        ? (Settings.clockSeconds ? "h:mm:ss AP" : "h:mm AP")
        : (Settings.clockSeconds ? "HH:mm:ss" : "HH:mm")
    readonly property string time: Qt.formatDateTime(clock.date, root._pattern)
    readonly property string date: Qt.formatDateTime(clock.date, "ddd d MMM")
    readonly property int hours: clock.hours
    readonly property int minutes: clock.minutes
}
