pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Timers and alarms set from the calendar card.
//
// Both are one thing here: an instant on the wall clock and a line of text. A
// timer is resolved to that instant the moment it is set rather than carried
// around as a remaining duration, so a reminder outlives a shell reload without
// drifting by however long the reload took.
Singleton {
    id: root

    // Soonest first, held here and written to disk on every change, so a timer
    // set now is still set after a reload, a logout or a reboot.
    // [{ id, at: <ms since the epoch>, text }]
    property var list: []
    readonly property int count: list.length
    readonly property var next: count > 0 ? list[0] : null

    // Republished once a second by the ticker below, so the countdowns in the
    // calendar all read one clock instead of each holding a timer of its own.
    property double now: Date.now()

    // Runs only while something is pending: an empty list has nothing to count
    // down and nothing to fire.
    Timer {
        interval: 1000
        repeat: true
        running: root.count > 0
        onTriggered: root._tick()
    }

    // Plain JSON rather than a JsonAdapter: an adapter's properties are applied
    // a frame after they are assigned, so a write made in the same frame as the
    // change it was meant to save missed it.
    FileView {
        id: store

        path: Quickshell.statePath("reminders.json")
        // Nothing is wrong with having no reminders file yet.
        printErrors: false

        // The file is read asynchronously, so this is where a saved list
        // actually arrives.
        onLoaded: root.list = root._parse(store.text())
    }

    // Distinguishes two reminders set for the same minute, so removing one from
    // the list cannot take the other with it.
    property int _seq: 0

    // A reminder that came due while the shell was down fires on the first tick
    // after it returns: late is what a missed alarm is, silent is worse.
    function _tick() {
        now = Date.now();

        const due = list.filter(r => r.at <= now);
        if (due.length === 0)
            return;

        for (const r of due)
            _fire(r);
        _store(list.filter(r => r.at > now));
    }

    function _fire(r) {
        // Sent the same way any other app would send it, so the card the bar
        // draws, the badge on the bell and the entry in the panel are the ones
        // already written for notifications.
        // No -i: an icon name the theme does not have resolves to a broken
        // image, and the card draws that as a checkerboard rather than as
        // nothing. The name "Reminder" on the card is the whole label it needs.
        Quickshell.execDetached(["notify-send", "-a", "Reminder",
                                 "-u", "critical", "Reminder", r.text]);
        // The sound is the part the notification cannot do, and an alarm nobody
        // hears is not an alarm. Plays under do-not-disturb, which suppresses
        // the toast and not the reminder.
        Quickshell.execDetached(["canberra-gtk-play", "-i", "alarm-clock-elapsed"]);
    }

    function _parse(text) {
        try {
            const saved = JSON.parse(text);
            return Array.isArray(saved) ? _sorted(saved) : [];
        } catch (e) {
            // A file we cannot read is a file we are about to replace: reminders
            // are not worth refusing to start over.
            return [];
        }
    }

    function _sorted(items) {
        return items.slice().sort((a, b) => a.at - b.at);
    }

    // The list is the truth the moment it changes; the file catches up on the
    // next pass of the event loop. Several changes in one frame -- a reminder
    // firing and leaving the list, a chip clicked twice -- then write the file
    // once, from the list they settled on, instead of queueing a write each and
    // leaving which one lands to chance.
    Timer {
        id: flush

        interval: 0
        onTriggered: store.setText(JSON.stringify(root.list))
    }

    function _store(items) {
        list = _sorted(items);
        flush.restart();
    }

    // `at` is milliseconds since the epoch. An instant already past is accepted
    // rather than refused -- it fires on the next tick, which is what a timer of
    // zero minutes means.
    function add(at, text) {
        // Kept fresh here as well as in the ticker: the first countdown drawn
        // for a reminder is drawn before the ticker has run once.
        now = Date.now();
        _store([...list, { id: `${Date.now()}-${_seq++}`, at: at, text: text !== "" ? text : "Reminder" }]);
    }

    function addIn(minutes, text) {
        add(Date.now() + minutes * 60000, text);
    }

    function remove(id) {
        _store(list.filter(r => r.id !== id));
    }
}
