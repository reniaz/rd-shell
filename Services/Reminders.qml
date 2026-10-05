pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Timers, one-offs and repeating reminders set from the calendar card.
//
// A timer is resolved to an instant on the wall clock the moment it is set
// rather than carried around as a remaining duration, so a reminder outlives
// a shell reload without drifting by however long the reload took. A
// repeating reminder is carried the same way: `at` is always its NEXT future
// occurrence, never "every day at 9" as a rule evaluated on the fly -- a
// Repeater bound to `list` (the dashboard calendar pane's Upcoming list) only
// ever has to read `at`, same as a one-off.
Singleton {
    id: root

    // Soonest first, held here and written to disk on every change, so a
    // reminder set now is still set after a reload, a logout or a reboot.
    // [{ id, at: <ms, next occurrence>, text, allDay, repeat, anchor? }]
    // `anchor` is the day-of-month (monthly/yearly) and month (yearly) the
    // series was created on, kept so a monthly series created on the 31st
    // still asks for the 31st after wintering through February -- without it
    // the day clamped down to 28 would never climb back up. Absent on
    // "none"/"daily"/"weekly" records and on anything migrated from v1.
    property var list: []
    readonly property int count: list.length
    readonly property var next: count > 0 ? list[0] : null

    // Republished once a second by the ticker below, so the countdowns in the
    // calendar all read one clock instead of each holding a timer of its own.
    property double now: Date.now()

    // Offered to the compose row / repeat chips; ids match the `repeat` field.
    readonly property var repeats: [
        { id: "none", name: "Once" },
        { id: "daily", name: "Daily" },
        { id: "weekly", name: "Weekly" },
        { id: "monthly", name: "Monthly" },
        { id: "yearly", name: "Yearly" }
    ]

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
        // actually arrives -- and where it arrives again after every write,
        // since a file we have just written counts as loaded.
        onLoaded: {
            root._adopt(store.text());
            root._loaded = true;
        }
        // A missing file reports loadFailed, not loaded (same as
        // StickyNotes.qml) -- without this a first-ever reminder could never
        // be written out at all.
        onLoadFailed: root._loaded = true
    }

    // `flush` refuses to write until the first read has resolved, so a change
    // made in the instant after a reload -- `list` still its empty default,
    // the file not yet read -- can never write that emptiness over reminders
    // really on disk. Same guard, same reason, as StickyNotes.qml's `_loaded`.
    property bool _loaded: false

    // Distinguishes two reminders set for the same minute, so removing one from
    // the list cannot take the other with it.
    property int _seq: 0

    // A reminder that came due while the shell was down fires on the first
    // tick after it returns: late is what a missed alarm is, silent is worse.
    // A repeating series missed for days (a laptop closed over a long
    // weekend) fires exactly once for the catch-up, then carries the SAME
    // record forward to its next future slot -- `_advance` is run in a loop
    // here rather than once, so "daily, missed for 4 days" lands back on
    // today rather than notifying four times in the same second.
    function _tick() {
        now = Date.now();

        const due = list.filter(r => r.at <= now);
        if (due.length === 0)
            return;

        const updated = [];
        for (const r of list) {
            if (r.at > now) { updated.push(r); continue; }

            _fire(r);

            if (r.repeat === "none")
                continue; // one-off: fires once, then gone -- today's behaviour.

            let at = r.at;
            let guard = 10000; // a corrupt/huge `at` must not spin forever
            do { at = _advance(at, r.repeat, r.anchor); } while (at <= now && guard-- > 0);
            // No object spread -- this QML JS engine parses array spread
            // (used below, and in v1's `add`) but not `{ ...r }`.
            updated.push(Object.assign({}, r, { at: at }));
        }
        _store(updated);
    }

    function _fire(r) {
        // Sent the same way any other app would send it, so the card the bar
        // draws, the badge on the bell and the entry in the panel are the ones
        // already written for notifications. Routed through a real Process
        // (not Quickshell.execDetached) because this one needs an answer back:
        // `-w` (implied by --action, kept explicit for anyone reading the
        // command) holds notify-send open until the user picks "Snooze 10
        // min" or "Dismiss" -- or times it out -- and prints the action's
        // name to stdout when it does. The Process is its own child, so
        // waiting on it never blocks the shell. No -i: an icon name the theme
        // does not have resolves to a broken image, and the card draws that
        // as a checkerboard rather than as nothing. The name "Reminder" on
        // the card is the whole label it needs.
        notifyComponent.createObject(root, {
            reminder: r,
            command: ["notify-send", "-a", "Reminder", "-u", "critical", "-w",
                      "--action=snooze=Snooze 10 min", "--action=dismiss=Dismiss",
                      "Reminder", r.text],
            running: true
        });
        // The sound is the part the notification cannot do, and an alarm
        // nobody hears is not an alarm. Plays under do-not-disturb, which
        // suppresses the toast and not the reminder.
        Quickshell.execDetached(["canberra-gtk-play", "-i", "alarm-clock-elapsed"]);
    }

    // One of these per fired reminder, not one static instance shared between
    // them: two reminders due in the same tick each get their own notify-send
    // waiting on its own answer, same as two toasts can be on screen together.
    Component {
        id: notifyComponent

        Process {
            id: proc

            // The record as it stood the moment it fired. By the time the
            // user answers, `_tick` has already dropped it (one-off) or moved
            // it to its next occurrence (series), so the answer works from
            // this copy, never from a lookup in `list`.
            property var reminder: null

            stdout: StdioCollector {
                onStreamFinished: {
                    // Deliberately not `root.snooze(id)`: a fired one-off is
                    // no longer in `list` for it to find, which made the
                    // button a silent no-op. Snoozing anything that has
                    // already fired is the same thing either way -- a fresh
                    // one-off ten minutes out -- which is what snooze() gives
                    // a series too.
                    if (this.text.trim() === "snooze")
                        root.add(Date.now() + 10 * 60000, proc.reminder.text, { allDay: proc.reminder.allDay });
                    // "dismiss", a timeout or a plain close all print nothing
                    // worth acting on -- the fired occurrence is already
                    // dropped (one-off) or advanced (series) by `_tick`.
                }
            }

            // Read after the process has actually exited, not merely once
            // stdout closes -- same reasoning as StickyNotes.qml's
            // cursorQuery: a failed spawn never produces a stream to finish,
            // and this is the one signal guaranteed to fire either way.
            onExited: proc.destroy()
        }
    }

    // Only a list we could actually read is allowed to replace the one being
    // held, and only when it differs from it.
    //
    // Two things come through onLoaded that must not land. One is the file we
    // have just written being reported back: the chips in the calendar are a
    // Repeater over `list`, and handing it a fresh array identity rebuilds every
    // one of them -- so saving a reminder would destroy the chip in the middle
    // of the animation that was introducing it. The other is an unreadable or
    // half-written file, which used to resolve to an empty list; that emptied
    // the calendar, and the next save then wrote the emptiness to disk and lost
    // timers the user really had set.
    function _adopt(text) {
        const parsed = _parse(text);
        if (parsed === null) return;
        if (JSON.stringify(parsed) === JSON.stringify(root.list)) return;

        root.list = parsed;
    }

    // v2: every record gets every field defaulted, so a v1 file (`{id, at,
    // text}` only, no `allDay`/`repeat`/`anchor`) and a v2 file read the same
    // way everywhere else in this singleton and in the QML that binds to
    // `list`. The one live reminder on disk is exactly a v1 record, and this
    // is the only place it is ever touched on the way in.
    function _parse(text) {
        try {
            const saved = JSON.parse(text);
            if (!Array.isArray(saved)) return null;
            return _sorted(saved.map(_defaulted));
        } catch (e) {
            return null;
        }
    }

    function _defaulted(r) {
        const d = {
            id: r.id,
            at: r.at,
            text: r.text,
            allDay: r.allDay ?? false,
            repeat: r.repeat ?? "none"
        };
        if (r.anchor) d.anchor = r.anchor;
        return d;
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
        onTriggered: {
            if (!root._loaded) { flush.restart(); return; } // see `_loaded`
            store.setText(JSON.stringify(root.list));
        }
    }

    function _store(items) {
        list = _sorted(items);
        flush.restart();
    }

    // The day-of-month (and, for yearly, the month) a repeat series is
    // anchored to -- undefined for "none"/"daily"/"weekly", which never clamp.
    function _anchorFor(atMs, repeat) {
        if (repeat !== "monthly" && repeat !== "yearly")
            return undefined;
        const d = new Date(atMs);
        return { day: d.getDate(), month: d.getMonth() };
    }

    // Day 0 of next month is the last day of this one -- the one Date trick
    // this needs rather than a hand-written table of month lengths and leap
    // years.
    function _daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    // Calendar-date arithmetic, not epoch-ms arithmetic: setDate/setMonth/
    // setFullYear work in LOCAL wall-clock fields, so "the same time tomorrow"
    // stays the same time tomorrow across a DST transition instead of
    // sliding an hour the way `at + 86400000` would. Monthly/yearly clamp to
    // the anchor day-of-month, falling back onto the day the record is
    // currently sitting on when there is no anchor (a record from before
    // this field existed) -- degraded but never wrong in a way that loses the
    // reminder.
    function _advance(atMs, repeat, anchor) {
        const d = new Date(atMs);
        switch (repeat) {
        case "daily":
            d.setDate(d.getDate() + 1);
            break;
        case "weekly":
            d.setDate(d.getDate() + 7);
            break;
        case "monthly": {
            const day = anchor?.day ?? d.getDate();
            // Land on a day every month has before changing the month, so a
            // 31st never spills into the month after the short one it would
            // otherwise overflow into.
            d.setDate(1);
            d.setMonth(d.getMonth() + 1); // rolls the year on its own past December
            d.setDate(Math.min(day, _daysInMonth(d.getFullYear(), d.getMonth())));
            break;
        }
        case "yearly": {
            const day = anchor?.day ?? d.getDate();
            const month = anchor?.month ?? d.getMonth();
            d.setDate(1);
            d.setMonth(month);
            d.setFullYear(d.getFullYear() + 1);
            d.setDate(Math.min(day, _daysInMonth(d.getFullYear(), month)));
            break;
        }
        }
        return d.getTime();
    }

    // `at` is milliseconds since the epoch. An instant already past is accepted
    // rather than refused -- it fires on the next tick, which is what a timer of
    // zero minutes means. `opts` optional: {allDay, repeat}.
    function add(at, text, opts) {
        // Kept fresh here as well as in the ticker: the first countdown drawn
        // for a reminder is drawn before the ticker has run once.
        now = Date.now();
        const o = opts ?? {};
        const repeat = o.repeat ?? "none";
        const id = `${Date.now()}-${_seq++}`;
        const r = {
            id: id,
            at: at,
            text: text !== "" ? text : "Reminder",
            allDay: o.allDay ?? false,
            repeat: repeat
        };
        const anchor = _anchorFor(at, repeat);
        if (anchor) r.anchor = anchor;
        _store([...list, r]);
        return id;
    }

    function addIn(minutes, text) {
        return add(Date.now() + minutes * 60000, text);
    }

    // Merges any of {at, text, allDay, repeat}. Touching `at` or `repeat`
    // re-derives `anchor` from the result (a user picking a new date for a
    // monthly reminder means THAT day is the new anchor); leaving both alone
    // -- editing just the text, say -- leaves `anchor` exactly as it was, so
    // editing the text of an already-clamped Jan-31-monthly occurrence can
    // never quietly truncate its anchor down to the clamped day.
    function update(id, fields) {
        _store(list.map(r => {
            if (r.id !== id) return r;
            const merged = Object.assign({}, r, fields); // see _tick's note on object spread
            if ("at" in fields || "repeat" in fields) {
                const anchor = _anchorFor(merged.at, merged.repeat);
                if (anchor) merged.anchor = anchor;
                else delete merged.anchor;
            }
            return merged;
        }));
    }

    function remove(id) {
        _store(list.filter(r => r.id !== id));
    }

    // A pending one-off is just rescheduled. A repeating series is left
    // alone and gets a one-off copy instead -- snoozing "take the pills"
    // ten minutes out must not cost tomorrow's dose.
    function snooze(id, minutes) {
        const r = list.find(x => x.id === id);
        if (!r) return;
        if (r.repeat === "none")
            update(id, { at: Date.now() + minutes * 60000 });
        else
            add(Date.now() + minutes * 60000, r.text, { allDay: r.allDay });
    }

    // Every occurrence in [from, to), sorted. Repeats are walked forward from
    // their stored `at` (always a future occurrence already, so there is
    // nothing earlier in a missed series worth surfacing) with the same
    // `_advance` the ticker uses, so a widget asking "what's on day X" and
    // the ticker that fires on day X agree about when X actually is.
    function occurrences(fromMs, toMs) {
        const out = [];
        for (const r of list) {
            if (r.repeat === "none") {
                if (r.at >= fromMs && r.at < toMs)
                    out.push({ id: r.id, at: r.at, text: r.text, allDay: r.allDay, repeat: r.repeat });
                continue;
            }

            let at = r.at;
            let guard = 10000; // a far-future `to` on a daily series must still end
            while (at < toMs && guard-- > 0) {
                if (at >= fromMs)
                    out.push({ id: r.id, at: at, text: r.text, allDay: r.allDay, repeat: r.repeat });
                at = _advance(at, r.repeat, r.anchor);
            }
        }
        return out.sort((a, b) => a.at - b.at);
    }

    function onDay(date) {
        const start = new Date(date);
        start.setHours(0, 0, 0, 0);
        const end = new Date(start);
        end.setDate(end.getDate() + 1);
        return occurrences(start.getTime(), end.getTime());
    }
}
