pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Backs the launcher's inline calculator (idea 5): a query that looks like
// arithmetic gets a synthetic result row above the app matches. Evaluation
// runs in a one-shot Process, the same spawn-per-answer idiom Services/Disk.qml
// uses for `df` -- never a process per keystroke. Every call to `submit()`
// only restarts a debounce Timer; only the timer firing ever spawns.
//
// Evaluation is `qalc -t` (the qalculate package, listed in install.sh), so
// unit and currency conversion work too: "5 km to mi", "=2^10", "sqrt(2)".
// Prefix the target unit with "-" to turn off mixed units ("5 km to -mi").
Singleton {
    id: root

    // The expression actually evaluated and its answer, echoed back together
    // so Launcher.qml never has to reconcile a stale expression with a fresh
    // result. Both go blank together too, via `_clear()`.
    property string expression: ""
    property string result: ""

    readonly property bool hasResult: root.result !== ""

    // What Launcher.qml calls on every keystroke. A non-arithmetic query (or
    // an empty one) clears any standing result immediately rather than
    // leaving a stale answer from the previous query sitting above the list.
    function submit(query) {
        const t = (query ?? "").trim();
        if (!root._looksLikeExpr(t)) {
            root._debounce.stop();
            root._pending = "";
            root._clear();
            return;
        }
        root._pending = t.startsWith("=") ? t.slice(1).trim() : t;
        root._debounce.restart();
    }

    // Enter on the synthetic row: copy the answer, same shape as any other
    // launcher action closing over its own result.
    function copyResult() {
        if (root.result !== "") Quickshell.execDetached(["wl-copy", root.result]);
    }

    function _clear() {
        root.expression = "";
        root.result = "";
    }

    property string _pending: ""
    // Bumped on every spawn; a Process result is only accepted if it still
    // matches the seq that launched it, so an answer that lands after the
    // query has since changed (or been cleared) is dropped instead of
    // overwriting a newer, unrelated one.
    property int _seq: 0

    Timer {
        id: _debounceTimer
        // Same register as Apps.qml's rebuild debounce and Wallpapers.qml's
        // preview debounce: long enough that a fast typist's keystrokes
        // collapse into one spawn, short enough that the answer still feels
        // immediate once they pause.
        interval: 180
        onTriggered: root._spawn()
    }
    property alias _debounce: _debounceTimer

    function _spawn() {
        const expr = root._pending;
        if (!expr) { root._clear(); return; }
        if (_calcProcess.running) {
            // Already evaluating a previous keystroke's expression; try
            // again shortly rather than drop this one or overlap two runs.
            root._debounce.restart();
            return;
        }
        root._seq++;
        _calcProcess.mySeq = root._seq;
        _calcProcess.expr = expr;
        // timeout: a query like 9**9**9 would otherwise pin a core and leave
        // _calcProcess running forever, silently stalling every later query.
        _calcProcess.command = ["timeout", "2", "qalc", "-t", expr];
        _calcProcess.running = true;
    }

    Process {
        id: _calcProcess
        property int mySeq: 0
        property string expr: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (_calcProcess.mySeq !== root._seq) return; // superseded
                const out = this.text.trim();
                if (!out) { root._clear(); return; }
                root.expression = _calcProcess.expr;
                root.result = out;
            }
        }
    }

    // `=…` always counts. Otherwise the query has to look unmistakably
    // arithmetic, not merely start with a digit -- a bare number ("2026")
    // must still fall through to plain app search, so a numeric start also
    // needs an operator, a unit-conversion "to", or a parenthesis before this
    // returns true.
    function _looksLikeExpr(t) {
        if (!t) return false;
        if (t.startsWith("=")) return true;
        const startsNumeric = /^[-+]?(\d+\.?\d*|\.\d+)/.test(t);
        const startsFunc = /^(sqrt|log|ln|sin|cos|tan|abs|pow)\s*\(/i.test(t);
        if (startsFunc) return true;
        if (!startsNumeric) return false;
        return /[+\-*/^%(]/.test(t) || /\bto\b/i.test(t);
    }
}
