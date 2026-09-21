pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Lifetime account history: what every Claude Code session this machine has
// ever recorded actually cost, and how it breaks down.
//
// A singleton of its own rather than more surface on ClaudeSession, for the
// same reason ClaudeDetail is one: the two poll loops have nothing to do with
// each other. ClaudeSession reads small state files every 2s to answer "what is
// happening now"; this parses 200MB of transcript to answer "what has happened,
// ever", and the answer only moves as fast as you can spend money.
Singleton {
    id: root

    readonly property var data: root._data
    readonly property bool ready: root._data !== null

    // Every section is exposed separately so a view binds to the one list it
    // draws. The payload is replaced wholesale on every accepted refresh, so a
    // view bound to `data` would rebuild all of its Repeaters for a change in
    // any of them.
    readonly property var totals: root._data?.totals ?? null
    readonly property var projects: root._data?.projects ?? []
    readonly property var models: root._data?.models ?? []
    readonly property var days: root._data?.days ?? []
    readonly property var hours: root._data?.hours ?? []
    readonly property var weekdays: root._data?.weekdays ?? []
    readonly property var tools: root._data?.tools ?? []
    readonly property var sessions: root._data?.sessions ?? []

    property var _data: null
    property string _sig: ""

    // The scan is incremental against a per-file cache, so a refresh that finds
    // nothing new costs ~0.1s. The first one after a fresh install parses the
    // whole corpus and costs a few seconds -- which is why it happens on a
    // timer in the background rather than when a tab is opened.
    property bool _busy: false

    function refresh() {
        if (root._busy) return;
        root._busy = true;
        query.running = true;
    }

    function _accept(text) {
        root._busy = false;

        // An identical payload must not be reassigned: every chart in the
        // Statistics tab is a Repeater over one of the lists above, and a fresh
        // object identity resets all of them mid-animation.
        if (text === root._sig) return;

        try {
            const next = JSON.parse(text);
            if (!next || !next.totals) return;

            // The script's contract is that it always exits 0 and always prints
            // one complete object, which is right for a poller -- but it means
            // a missing jq, an unreadable projects directory or a jq pass that
            // aborted all arrive here as a perfectly valid payload of zeroes.
            // Publishing that would walk every total, bar and donut down to
            // nothing and back up again on the next good scan, and a reader
            // would take it for "the account was reset" rather than for "one
            // refresh failed". A scan that claims no sessions at all is only
            // believed while there is nothing better already on screen.
            if (root._data !== null && (next.totals.sessions ?? 0) === 0) return;

            root._sig = text;
            root._data = next;
        } catch (e) {
            // keep the last good payload
        }
    }

    Process {
        id: query

        command: ["sh", Quickshell.shellPath("scripts/claude-global.sh")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root._accept(this.text)
        }

        // _busy is the only thing keeping two scans of a 200MB corpus from
        // overlapping, and the collector clears it when stdout closes. A run
        // that ends without that ever happening -- killed, or a script that is
        // not on disk -- would latch it true and quietly retire the refresh
        // timer for the rest of the session, leaving the panel frozen on
        // whatever it last read. Clearing it here too costs nothing on the
        // ordinary path, where it is already false by the time we arrive.
        onExited: root._busy = false
    }

    // Two minutes: the numbers here are cumulative and a single turn moves the
    // total by cents, so there is nothing to gain from asking more often -- and
    // the refresh is only cheap while the cache is warm.
    //
    // Only while the panel is up, though. The expensive scan is the first one,
    // and that runs at startup above, so the per-file cache is warm long before
    // anyone opens the window; from then on the last payload simply stays
    // standing, which is what lets a reopened panel paint its charts fully
    // formed instead of sweeping up from zero. The panel also refreshes once on
    // open. Polling a closed panel would only spend half a second of jq every
    // two minutes to arrive at numbers nobody is looking at.
    Timer {
        interval: 120000
        running: ClaudeSession.panelOpen
        repeat: true
        onTriggered: root.refresh()
    }
}
