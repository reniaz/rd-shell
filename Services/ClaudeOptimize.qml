pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The token-budget rules the Optimize tab offers, and the one place that writes
// them. Modelled on Services/ClaudeGlobal.qml: a script owns every fact, this
// owns only the last answer it gave.
//
// Nothing here is polled. The rules describe two files that change when the user
// changes them, so the tab refreshes when it opens and after every write, and a
// timer would only be asking the same question of the same bytes.
Singleton {
    id: root

    readonly property var rules: root._data ? (root._data.rules ?? []) : []
    readonly property bool ready: root._data !== null
    readonly property bool needsSudo: root._data ? (root._data.needsSudo ?? false) : false
    readonly property int appliedCount: root._data ? (root._data.appliedCount ?? 0) : 0
    readonly property int totalCount: root._data ? (root._data.totalCount ?? 0) : 0

    readonly property string error: root._error
    readonly property bool busy: root._busy

    // Written by the tab's password field and read exactly once, by the process
    // that needs it. Cleared the instant it has been handed over: a sudo
    // password sitting in a singleton for the rest of the session is a
    // password waiting to be read out of a crash dump.
    property string password: ""

    property var _data: null
    property string _sig: ""
    property string _error: ""
    property bool _busy: false

    function refresh() { root._run("status", ""); }
    function apply(id) { root._run("apply", id); }
    function revert(id) { root._run("revert", id); }
    function applyAll() { root._run("apply-all", ""); }

    function _run(verb, id) {
        if (root._busy) return;

        root._busy = true;
        root._error = "";

        const script = Quickshell.shellPath("scripts/claude-optimize.sh");
        const args = id === "" ? [verb] : [verb, id];

        // Status is a read, and a read that cannot open a file reports it
        // rather than failing -- so only a write is ever worth a password.
        const elevate = verb !== "status" && root.needsSudo;

        // CLAUDE_HOME is carried explicitly because sudo replaces HOME with
        // /root, and the script would then describe root's Claude install
        // instead of the user's.
        query.command = elevate
            ? ["sudo", "-S", "-p", "", "env",
               "CLAUDE_HOME=" + (Quickshell.env("HOME") ?? ""),
               "sh", script].concat(args)
            : ["sh", script].concat(args);

        query.elevated = elevate;
        query.stdinEnabled = elevate;
        query.running = true;
    }

    function _accept(text) {
        // An identical payload must not be reassigned: the tab is a Repeater
        // over `rules`, and a fresh object identity rebuilds every row.
        if (text === root._sig) return;

        try {
            const next = JSON.parse(text);
            if (!next || !Array.isArray(next.rules)) return;
            root._sig = text;
            root._data = next;
            if ((next.error ?? "") !== "") root._error = next.error;
        } catch (e) {
            // keep the last good payload
        }
    }

    Process {
        id: query

        // Whether this run was launched under sudo, which decides both that a
        // password is owed on stdin and how a non-zero exit should be read.
        property bool elevated: false

        command: ["sh", Quickshell.shellPath("scripts/claude-optimize.sh")]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root._accept(this.text)
        }

        // Written on started rather than before running: the process has no
        // stdin to write to until it exists.
        onStarted: {
            if (!query.elevated) return;
            query.write(root.password + "\n");
            root.password = "";
        }

        onExited: (exitCode, exitStatus) => {
            root._busy = false;
            query.stdinEnabled = false;

            // The script always exits 0 and always prints JSON, so a non-zero
            // code from an elevated run came from sudo itself -- and the only
            // one worth naming is the wrong password.
            if (query.elevated && exitCode !== 0)
                root._error = "sudo: authentication failed";

            query.elevated = false;
        }
    }
}
