pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The expanded session and its on-demand transcript scan. Deliberately a
// singleton of its own rather than more surface on ClaudeSession: the two poll
// loops have nothing to do with each other -- 2s and cheap against ~/.claude
// state files, 5s and expensive against a whole transcript -- and this way
// neither singleton has to know the other exists.
Singleton {
    id: root

    // "" means nothing is expanded. Writable, but expand()/collapse() are the
    // sane way in; the work all hangs off the change handler below so either
    // route behaves identically.
    property string sessionId: ""

    readonly property var data: root._data
    readonly property bool loading: root._loading

    property var _data: null
    property bool _loading: false

    // Last good payload per session id. Re-expanding a row you looked at a
    // minute ago paints that scan immediately and refreshes underneath, instead
    // of flashing an empty dashboard for as long as the scan takes.
    property var _cache: ({})

    // Signatures of those payloads, same discipline as ClaudeSession._sig: an
    // identical 5s refresh must not rebuild the activity Repeater out from
    // under whoever is reading it. Mutated in place on purpose.
    property var _sig: ({})

    // The id the running scan was launched for. A scan for the row you just
    // collapsed still runs to completion, and without this its stdout would
    // arrive later and paint under the next row's header.
    property string _pending: ""

    function expand(id) {
        root.sessionId = (id === "" || id === root.sessionId) ? "" : id;
    }

    function collapse() {
        root.sessionId = "";
    }

    // The last payload for a row that is no longer open, kept deliberately.
    // ClaudeSessionRow folds its drawer shut over 200ms and keeps the content
    // loaded for exactly that long, on purpose -- so blanking `_data` the
    // instant the row collapses would empty every figure inside a drawer the
    // user can still see closing, which reads as the numbers falling out of it
    // rather than as the drawer sliding away. Consumers already gate on
    // `data.sessionId`, so a payload left standing for the row that is closing
    // is invisible to every other row, and the next accepted scan replaces it.
    function payloadFor(id) {
        return root._cache[id] ?? null;
    }

    onSessionIdChanged: {
        root._pending = "";
        query.running = false;
        root._loading = false;

        // Nothing expanded: stop the polling, leave the reading standing.
        if (root.sessionId === "") return;

        // A row we have looked at before paints immediately and refreshes
        // underneath; one we have not leaves the previous row's payload in
        // place, where it belongs to a drawer that is still folding shut and is
        // ignored by the one folding open.
        const cached = root._cache[root.sessionId];
        if (cached) root._data = cached;

        root._launch();
    }

    // ListView destroys delegates the moment they scroll out of view, so a
    // Process living in a row would be SIGTERMed mid-scan and relaunched on the
    // way back -- and the panel itself sits inside a LazyLoader that tears the
    // window down 260ms after it closes. Both are why this lives here.
    function _launch() {
        if (root.sessionId === "") return;

        // command only takes effect at the next launch, so the argument cannot
        // simply be reassigned under a running process. Stopping first also
        // ends any in-flight scan's stream while _pending still names the row
        // it was launched for, so its half-written stdout is dropped rather
        // than credited to this one.
        query.running = false;

        root._pending = root.sessionId;
        root._loading = true;
        query.exec(["sh", Quickshell.shellPath("scripts/claude-session.sh"), root.sessionId]);
    }

    function _changed(id, value) {
        const s = JSON.stringify(value);
        if (root._sig[id] === s) return false;
        root._sig[id] = s;
        return true;
    }

    // The scan script always exits 0 and always prints one complete object, so
    // a transcript it could not find, or a missing jq, arrives as a valid
    // payload of zeroes carrying the right session id. That is indistinguishable
    // from a good answer by shape alone, and accepting one would drain every
    // economics figure in an open drawer to zero until the next scan landed.
    // It is only believable while we have nothing else for that row.
    function _blank(p) {
        return (p.economics?.turns ?? 0) === 0
            && (p.activity ?? []).length === 0
            && (p.subagents ?? []).length === 0;
    }

    function _accept(text) {
        const forId = root._pending;
        root._pending = "";

        // Collapsed, or already moved on to another row, while this scan ran.
        if (forId === "" || forId !== root.sessionId) return;

        root._loading = false;

        try {
            const next = JSON.parse(text);
            // The script echoes the id back precisely so a reply can be matched
            // rather than trusted.
            if (!next || next.sessionId !== forId) return;
            if (root._cache[forId] && root._blank(next)) return;

            root._cache[forId] = next;
            if (root._changed(forId, next)) root._data = next;
        } catch (e) {
            // keep whatever is already on screen
        }
    }

    Process {
        id: query

        stdout: StdioCollector {
            onStreamFinished: root._accept(this.text)
        }
    }

    // Only ticks while a row is open, so a shut panel costs nothing. A finished
    // Process drops to running:false, so re-arming it is the poll.
    Timer {
        interval: 5000
        running: root.sessionId !== ""
        repeat: true
        onTriggered: root._launch()
    }
}
