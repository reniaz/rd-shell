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
    }

    // Two minutes: the numbers here are cumulative and a single turn moves the
    // total by cents, so there is nothing to gain from asking more often -- and
    // the refresh is only cheap while the cache is warm.
    Timer {
        interval: 120000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
