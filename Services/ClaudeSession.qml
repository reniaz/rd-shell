pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.Config

Singleton {
    id: root

    // Owned here rather than by the panel, so the pill, the panel and the IPC
    // handler all read one source of truth (same shape as Services/Notifications.qml).
    property bool panelOpen: false

    // Held true while the panel slides back out, so the LazyLoader does not rip
    // the window away mid-animation. closePanel() sets it BEFORE clearing
    // panelOpen, so the loader never sees both false at once.
    property bool panelClosing: false

    // Last good parse, held one section per property. Reassigning a var property
    // with a fresh object always signals a change, which resets every ListView
    // and Repeater bound to it -- so each section is only swapped in when its
    // serialised form actually differs. Jobs and limits then sit perfectly
    // still, and so do sessions whenever nothing is happening.
    property var _sessions: []
    property var _jobs: []
    property var _limits: null

    // Signatures of the values above. Nothing binds to it, so mutating it in
    // place is deliberate: it must not itself trigger a re-render.
    property var _sig: ({})

    // Read by ago() and uptime() so their bindings re-run on a slow clock. A card
    // whose data has not changed is never rebuilt, and its "3m ago" would
    // otherwise freeze at whatever it said when the card was created.
    property int _tick: 0

    // A second, faster clock read only by elapsed(). Elapsed-in-turn has to move
    // every second to read as live, which is far too often for the "3m ago"
    // strings above -- they would repaint fifteen times for every change they
    // actually show.
    property int _fastTick: 0

    readonly property var sessions: root._sessions
    readonly property int sessionCount: root.sessions.length
    readonly property bool available: root.sessionCount > 0

    readonly property var jobs: root._jobs
    readonly property var limits: root._limits

    // Any live session working. Global on purpose: the pill stands for Claude as
    // a whole, so it must not go quiet because the session that happens to have
    // spoken last is the one sitting idle.
    readonly property bool busy: root.sessions.some(s => s.status === "busy")

    // Header counts. Sessions blocked on a human are counted apart from sessions
    // merely thinking, because they are the only ones that want you to act.
    readonly property int busyCount: root.sessions.filter(s => s.status === "busy").length
    readonly property int waitingCount: root.sessions.filter(s => (s.waitingFor ?? "") !== "").length

    // Account-wide five-hour usage. This is what "claude usage" means to whoever
    // glances at the bar; per-session context lives on the panel's session rows.
    // -1 when nothing has been cached yet, so the pill can drop the label rather
    // than assert a confident 0%.
    // The _tick guard is never true; reading _tick is what keeps this binding on
    // the slow clock, so the reset below is noticed while limits sit unchanged.
    readonly property int usagePercent: {
        if (root._tick < 0) return -1;

        const l = root.limits;
        if (!l) return -1;

        // Past its reset instant the cached figure describes a window that has
        // already ended, and the new one necessarily starts empty. Reporting the
        // old number pins the pill at 100% long after the limit actually lifted.
        if (l.fiveHourResets && Date.parse(l.fiveHourResets) <= Date.now()) return 0;

        return l.fiveHour ?? 0;
    }

    // ── the session + job table ───────────────────────────────────────────
    // A ListModel and not a JS array. Reassigning a var array signals a whole-
    // model reset, which destroys every delegate: with an accordion that
    // collapses the open row and drops the scroll position twice a second.
    // setProperty on one role of one row re-evaluates only that delegate's
    // bindings and leaves the delegate, its hover state and its open drawer
    // exactly where they were.
    readonly property ListModel rows: rowModel

    ListModel { id: rowModel }

    // ── formatting shared by the pill and every panel tab ─────────────────
    // These are plain functions rather than bindings, so they only re-run when
    // the caller's own dependencies change -- which is every 2s, when _data is
    // replaced. That is the whole clock these relative times need.

    function _span(ms) {
        const s = Math.max(0, Math.round(ms / 1000));
        if (s < 60) return s + "s";
        const m = Math.floor(s / 60);
        if (m < 60) return m + "m";
        const h = Math.floor(m / 60);
        if (h < 24) return h + "h";
        return Math.floor(h / 24) + "d";
    }

    // Accepts an ISO string (transcripts, job timelines) or epoch seconds/ms
    // (plan mtimes come from stat, which reports seconds).
    // The _tick guard is never true; it is there so that reading _tick counts as
    // a binding dependency and cannot be optimised away. See _tick above.
    function ago(when) {
        if (root._tick < 0) return "";
        if (when === undefined || when === null || when === "") return "";
        const t = typeof when === "number" ? (when < 1e11 ? when * 1000 : when) : Date.parse(when);
        if (isNaN(t)) return "";
        return root._span(Date.now() - t) + " ago";
    }

    // Time remaining until an instant that is normally in the future -- ago()
    // would floor a rate-limit reset at "0s ago" and read as already past.
    function until(when) {
        if (root._tick < 0) return "";
        if (when === undefined || when === null || when === "") return "";
        const t = Date.parse(when);
        if (isNaN(t)) return "";
        return root._span(t - Date.now());
    }

    // Wall-clock instant of a reset, so "resets in 2h" can also say *when*.
    // Same _tick dependency trick as until(): the string must re-render when the
    // day rolls over, not freeze at whatever the binding first saw.
    function clockAt(when) {
        if (root._tick < 0) return "";
        if (when === undefined || when === null || when === "") return "";
        const t = Date.parse(when);
        if (isNaN(t)) return "";
        const d = new Date(t);
        // Spelled out rather than handed to toLocaleTimeString: the format is
        // asked for as "12:20 AM" specifically, and the system locale here would
        // render it 24-hour.
        let h = d.getHours();
        const half = h < 12 ? "AM" : "PM";
        h = h % 12;
        if (h === 0) h = 12;
        const hm = h + ":" + String(d.getMinutes()).padStart(2, "0") + " " + half;
        // Beyond today the hour alone is ambiguous, so the weekday is carried.
        const sameDay = d.toDateString() === new Date().toDateString();
        return sameDay ? hm : d.toLocaleDateString(Qt.locale(), "ddd") + " " + hm;
    }

    // Bare span since an epoch-ms instant, with no "ago" suffix: this is the
    // stopwatch on a turn in progress, not a note about the past.
    // The _fastTick guard is never true; it is there so that reading _fastTick
    // counts as a binding dependency and cannot be optimised away, exactly as
    // the _tick guard does in ago(). See _fastTick above.
    function elapsed(sinceEpochMs) {
        if (root._fastTick < 0) return "";
        if (!sinceEpochMs) return "";
        return root._span(Date.now() - sinceEpochMs);
    }

    function uptime(startedAt) {
        if (root._tick < 0) return "";
        if (!startedAt) return "";
        const s = Math.max(0, Math.floor((Date.now() - startedAt) / 1000));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    function compact(n) {
        if (typeof n !== "number" || !isFinite(n)) return "0";
        if (n >= 1000000) return (n / 1000000).toFixed(n >= 10000000 ? 0 : 1) + "M";
        if (n >= 1000) return Math.round(n / 1000) + "k";
        return String(n);
    }

    // Cents only below ten dollars. Above that they are four characters of noise
    // in a column whose whole point is which project is the expensive one, and
    // a lifetime total is grouped so four figures can be read at a glance.
    function money(n) {
        if (typeof n !== "number" || !isFinite(n)) return "$0";
        if (n < 10) return "$" + n.toFixed(2);
        const w = String(Math.round(n));
        return "$" + w.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    }

    // A duration in milliseconds spelled out to two units, which is as much as
    // any of these figures is accurate to.
    function duration(ms) {
        if (typeof ms !== "number" || !isFinite(ms) || ms <= 0) return "0m";
        const s = Math.round(ms / 1000);
        if (s < 60) return s + "s";
        const m = Math.floor(s / 60);
        if (m < 60) return m + "m";
        const h = Math.floor(m / 60);
        if (h < 24) return h + "h " + (m % 60) + "m";
        return Math.floor(h / 24) + "d " + (h % 24) + "h";
    }

    // The panel's one idea of "how bad is this percentage", so the context
    // meter, the plan meter and the two rate-limit meters cannot drift apart
    // the way their four copy-pasted ancestors already had.
    function levelColor(pct) {
        if (pct > 90) return Colors.claudeCritical;
        if (pct > 75) return Colors.claudeWarn;
        return Colors.claudeAccent;
    }

    // Dispatched exactly the way Services/Workspaces.qml dispatches, and for the
    // same reason: under a Lua config every dispatch is evaluated as Lua source,
    // so the native `focuswindow address:0x...` is a syntax error there -- Lua
    // reads `address:0x...` as a method call and rejects it -- whether it is
    // sent through Hyprland.dispatch or through hyprctl. That was the whole bug:
    // the button dispatched, Hyprland answered with a Lua parse error, and
    // nothing moved. hl.dsp.focus also carries the workspace switch, so one call
    // both raises the window and takes you to it.
    function focusWindow(address) {
        if (!address || address === "") return;
        if (Hyprland.usingLua) Hyprland.dispatch(`hl.dsp.focus({ window = "address:${address}" })`);
        else Hyprland.dispatch(`focuswindow address:${address}`);
    }

    // Dismisses a finished background job by deleting the directory the status
    // script discovers it through. The row is dropped here as well so the click
    // lands immediately instead of waiting out the 2s poll.
    //
    // _sig.jobs is deliberately left holding the pre-delete payload: a poll that
    // fires before the rm lands then still compares equal, so the job is not
    // written back into the table for one frame and then removed again.
    function dismissJob(id) {
        if (!id || id === "") return;

        Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/claude-job-rm.sh"), id]);

        root._jobs = root._jobs.filter(j => (j.id ?? "") !== id);
        root._reconcile(root._buildRows());
    }

    // True only when this section is genuinely different from the one on screen.
    function _changed(name, value) {
        const s = JSON.stringify(value);
        if (root._sig[name] === s) return false;
        root._sig[name] = s;
        return true;
    }

    // ── row normalisers ───────────────────────────────────────────────────
    // Every row in the model is built by one of these two, and both spell out
    // every single role. ListModel freezes its role set on the first insert, so
    // a role missing from the first row can never be written on any later one.
    // Every value is a scalar for a second reason: setProperty silently no-ops
    // when the new value changes type, so `plan` and `tool` are flattened here
    // rather than passed through as nested objects.

    function _sessionRow(s) {
        const limit = s.contextLimit ?? 0;
        const plan = s.plan ?? null;
        const tool = s.tool ?? null;
        const blocked = (s.waitingFor ?? "") !== "";

        return {
            rowType: "session",
            sessionId: s.sessionId ?? "",
            pid: s.pid ?? 0,
            project: s.project ?? "",
            name: s.name ?? "",
            cwd: s.cwd ?? "",
            window: s.window ?? "",
            state: blocked ? "waiting" : (s.status === "busy" ? "busy" : "idle"),
            waitingFor: s.waitingFor ?? "",
            // Epoch milliseconds, so it does not fit an int -- read it into a
            // `real` or a `var`, never an `int` property.
            statusSince: s.statusUpdatedAt ?? 0,
            ctxPct: limit > 0 ? Math.round((s.contextTokens ?? 0) / limit * 100) : 0,
            ctxTokens: s.contextTokens ?? 0,
            ctxLimit: limit,
            toolName: tool ? (tool.name ?? "") : "",
            toolTarget: tool ? (tool.target ?? "") : "",
            model: s.model ?? "",
            mode: s.mode ?? "",
            effort: s.effort ?? "",
            branch: s.branch ?? "",
            title: s.title ?? "",
            lastPrompt: s.lastPrompt ?? "",
            subagents: s.subagents ?? 0,
            planName: plan ? (plan.name ?? "") : "",
            planDone: plan ? (plan.done ?? 0) : 0,
            planOpen: plan ? (plan.open ?? 0) : 0,
            startedAt: s.startedAt ?? 0,
            lastActivity: s.lastActivity ?? "",
            jobDetail: "",
            jobTokens: 0,
            jobTasks: 0,
            jobQueued: 0
        };
    }

    function _jobRow(j) {
        const st = j.state ?? "";

        return {
            rowType: "job",
            sessionId: j.id ?? "",
            pid: 0,
            project: "",
            name: j.id ?? "",
            cwd: "",
            window: "",
            state: (st === "working" || j.tempo === "busy") ? "working"
                : (st === "done" ? "done" : "idle"),
            waitingFor: "",
            statusSince: 0,
            ctxPct: 0,
            ctxTokens: 0,
            ctxLimit: 0,
            toolName: "",
            toolTarget: "",
            model: "",
            mode: "",
            effort: "",
            branch: "",
            title: "",
            lastPrompt: "",
            subagents: 0,
            planName: "",
            planDone: 0,
            planOpen: 0,
            startedAt: 0,
            lastActivity: j.at ?? "",
            jobDetail: j.detail ?? "",
            jobTokens: j.tokens ?? 0,
            jobTasks: j.tasks ?? 0,
            jobQueued: j.queued ?? 0
        };
    }

    // Sessions arrive already sorted by the script -- see its ordering comment --
    // so nothing here re-sorts them. Jobs sit directly under the session that
    // owns them when the payload names one, and otherwise fall to the bottom.
    function _buildRows() {
        const out = root._sessions.map(s => root._sessionRow(s));

        for (const j of root._jobs) {
            const owner = (j.sessionId ?? "") === ""
                ? -1
                : out.findIndex(r => r.rowType === "session" && r.sessionId === j.sessionId);

            if (owner < 0) {
                out.push(root._jobRow(j));
                continue;
            }

            // Past any sibling jobs already placed, so several jobs on one
            // session keep the order the script emitted them in.
            let at = owner + 1;
            while (at < out.length && out[at].rowType === "job") at++;
            out.splice(at, 0, root._jobRow(j));
        }

        return out;
    }

    // Walks the model once, pulling each wanted row into place and writing only
    // the roles that actually differ. Rows the payload no longer carries fall
    // off the end in one remove.
    function _reconcile(next) {
        for (let i = 0; i < next.length; i++) {
            const want = next[i];

            let at = -1;
            for (let j = i; j < rowModel.count; j++) {
                const have = rowModel.get(j);
                if (have.rowType === want.rowType && have.sessionId === want.sessionId) {
                    at = j;
                    break;
                }
            }

            if (at < 0) {
                rowModel.insert(i, want);
                continue;
            }

            if (at !== i) rowModel.move(at, i, 1);

            const row = rowModel.get(i);
            for (const key in want) {
                if (row[key] !== want[key]) rowModel.setProperty(i, key, want[key]);
            }
        }

        if (rowModel.count > next.length)
            rowModel.remove(next.length, rowModel.count - next.length);
    }

    function _parse(text) {
        try {
            const next = JSON.parse(text);
            // A parse that succeeds but yields the wrong shape (an empty read
            // gives `null`) would wipe the panel just as surely as a throw.
            if (!next || !Array.isArray(next.sessions)) return;

            // _changed still gates sessions and jobs, but only to decide whether
            // the reconcile is worth running: the table itself is diffed row by
            // row below, not swapped wholesale.
            const sessionsChanged = root._changed("sessions", next.sessions);
            if (sessionsChanged) root._sessions = next.sessions;

            const jobs = next.jobs ?? [];
            const jobsChanged = root._changed("jobs", jobs);
            if (jobsChanged) root._jobs = jobs;

            if (sessionsChanged || jobsChanged) root._reconcile(root._buildRows());

            if (root._changed("limits", next.limits ?? null)) root._limits = next.limits ?? null;
        } catch (e) {
            // keep the last good value
        }
    }

    // Reads ~/.claude state files. Deliberately not the `claude` binary: that is
    // a 215MB bun process costing ~300ms and ~250MB RSS, every 2 seconds.
    Process {
        id: query

        command: ["sh", Quickshell.shellPath("scripts/claude-status.sh")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    // A finished Process drops to running:false, so re-arming it is the poll.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: query.running = true
    }

    // The account-wide rate-limit figures, which no local file tracks: the CLI
    // caches them in ~/.claude.json only while you have /usage open, so without
    // this the pill would sit on whatever percentage your last manual check
    // happened to see. Writes a cache file; claude-status.sh above picks it up
    // on its next pass, so nothing here parses the answer.
    Process {
        id: usageRefresh

        command: ["sh", Quickshell.shellPath("scripts/claude-usage.sh")]
        running: true
    }

    // A minute, not two seconds: this one leaves the machine, and the five-hour
    // window it reports moves in whole percent.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: usageRefresh.running = true
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root._tick++
    }

    // Gated rather than free-running: a per-second repaint of every row is worth
    // paying for only while the panel is on screen AND something is actually
    // counting up. With nothing busy it costs nothing at all.
    Timer {
        interval: 1000
        running: root.panelOpen && (root.busyCount > 0 || root.waitingCount > 0)
        repeat: true
        onTriggered: root._fastTick++
    }

    function openPanel() {
        releaseTimer.stop();
        panelClosing = false;
        panelOpen = true;
    }

    function closePanel() {
        if (!panelOpen) return;
        panelClosing = true;
        panelOpen = false;
        releaseTimer.restart();
    }

    // Releases the panel window once the slide-out has had time to finish.
    // Deliberately NOT driven by the animation's onFinished: inside a Behavior
    // that signal does not fire reliably, and when it is missed the layer
    // surface stays alive and silently eats clicks down the right of the screen.
    Timer {
        id: releaseTimer
        interval: 260
        onTriggered: root.panelClosing = false
    }

    function togglePanel() {
        if (panelOpen) closePanel();
        else openPanel();
    }
}
