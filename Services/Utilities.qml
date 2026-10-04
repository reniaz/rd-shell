pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.Config

// Backs UtilityTray.qml (Ctrl+Alt+U): the tray's own open flag, which screen
// it is allowed to open on, its QR/colour-pick binary checks, and the QR and
// colour-pick pipelines themselves.
//
// OCR is deliberately NOT run from here -- see Ocr.qml, which owns the whole
// slurp/grim/tesseract pipeline on its own so screen-region-ocr-translate-
// popup (idea 98's own first dependency) can drive it directly without this
// file in the loop at all; this tray just happens to be one more caller of
// it, through startOcr() below.
//
// The colour-pick pipeline (`startColor`/`_hyprpicker`) is deliberately its
// own small, self-contained piece -- "the hyprpicker mechanism" idea
// color-picker-hyprpicker-in-shell names as something to reuse once it
// builds its own standalone Pill, rather than reimplementing hyprpicker
// invocation a second time.
Singleton {
    id: root

    property bool panelOpen: false

    // Only the bar's own focused-screen gate exists in BarWindow.qml today,
    // and that file is not this round's to touch -- so this is the same
    // "sticky, not a live binding" idea in miniature, scoped to just this
    // tray. A plain live binding to Hyprland.focusedMonitor would go empty
    // the instant the tray itself grabs keyboard focus (WlrKeyboardFocus.
    // Exclusive), which would flip every screen's gate false on the very
    // frame it opened; latching onto the last real answer instead is what
    // keeps it open on the screen it was asked to open on.
    property string focusedScreen: Hyprland.focusedMonitor?.name
        ?? Quickshell.screens[0]?.name ?? ""

    Connections {
        target: Hyprland

        function onFocusedMonitorChanged() {
            const name = Hyprland.focusedMonitor?.name ?? "";
            if (name !== "") root.focusedScreen = name;
        }
    }

    // Re-checked on every open, same reason and same shape as Ocr.available
    // -- zbar-tools or hyprpicker could be (un)installed mid-session, and
    // nothing here should need a shell restart to notice either way.
    property bool qrAvailable: true
    property bool colorAvailable: true

    // Which tool's result -- if any -- is on screen right now.
    // "" | "ocr" | "qr" | "color"
    property string activeTool: ""

    // Mirrors whichever pipeline activeTool points at, so UtilityTray.qml
    // reads one pair of properties regardless of which tool ran:
    // "" idle (tool list), "done", "empty", "error". Every pipeline below
    // hides the tray for its own "capturing"/"working" stretch (see each
    // start* function), so by the time the tray is shown again `state` is
    // already one of the three terminal values here -- a cancelled slurp or
    // hyprpicker goes straight back to "" instead of ever landing in this
    // property at all. Kept anyway (rather than a plain bool) in case a
    // future caller reopens the tray mid-pipeline, which the idle/result
    // split below the pipelines still has to render something sane for.
    property string state: ""
    property string resultText: ""   // OCR text or QR/barcode payload
    property string resultColor: ""  // "#rrggbb" from the colour tool
    property string errorText: ""

    function togglePanel() {
        root.panelOpen = !root.panelOpen;
    }

    // Every open starts clean -- a tray that reopens still showing the last
    // run's result (or, worse, a stale mid-pipeline state) is confusing. The
    // one exception is a pipeline genuinely still in flight (the tray was
    // hidden mid-capture and reopened by a second keybind press before it
    // finished): that is left alone rather than reset out from under itself.
    onPanelOpenChanged: if (root.panelOpen) root._onOpened()

    function _onOpened() {
        if (root.activeTool === "" || root.state === "done" || root.state === "empty" || root.state === "error") {
            root.activeTool = "";
            root.state = "";
            root.resultText = "";
            root.resultColor = "";
            root.errorText = "";
            Ocr.reset();
        }
        Ocr.checkAvailable();
        if (!_checkTools.running)
            _checkTools.running = true;
    }

    function backToList() {
        root.activeTool = "";
        root.state = "";
        root.resultText = "";
        root.resultColor = "";
        root.errorText = "";
    }

    Process {
        id: _checkTools
        command: ["sh", "-c",
            "command -v zbarimg >/dev/null 2>&1 && echo 1 || echo 0; " +
            "command -v hyprpicker >/dev/null 2>&1 && echo 1 || echo 0"]
        property string _out: ""
        stdout: StdioCollector { onStreamFinished: _checkTools._out = this.text }
        onExited: {
            const lines = _checkTools._out.trim().split("\n");
            root.qrAvailable = lines[0] === "1";
            root.colorAvailable = (lines[1] ?? "1") === "1";
        }
    }

    // ── OCR: hands off to Ocr.qml entirely ──────────────────────
    function startOcr() {
        if (!Ocr.available || root.activeTool !== "") return;
        root.activeTool = "ocr";
        root.state = "";
        // Hide the tray before slurp runs -- the popup is exactly what is in
        // the way of the region someone is about to select. The Connections
        // block below re-shows it once Ocr.qml has something to report.
        root.panelOpen = false;
        Ocr.run();
    }

    Connections {
        target: Ocr

        function onStateChanged() {
            if (root.activeTool !== "ocr") return;
            if (Ocr.state === "") {
                // Cancelled (Esc in slurp) -- back to the idle tool list,
                // reopened rather than left closed, per the brief.
                root.activeTool = "";
                root.panelOpen = true;
                return;
            }
            root.state = Ocr.state;
            root.resultText = Ocr.text;
            root.errorText = Ocr.error;
            if (Ocr.state === "done" || Ocr.state === "empty" || Ocr.state === "error") {
                if (Ocr.state === "done") Quickshell.execDetached(["wl-copy", Ocr.text]);
                root.panelOpen = true;
            }
        }
    }

    // ── QR / barcode: its own slurp -> grim -> zbarimg ──────────
    function startQr() {
        if (!root.qrAvailable || root.activeTool !== "") return;
        root.activeTool = "qr";
        root.state = "";
        root.panelOpen = false;
        // Same slurp theming Ocr.qml's run() uses (see its own comment) --
        // dim outside the selection, clear selection, accent border -- so
        // hiding the tray is never mistaken for "nothing happened".
        // stdin from /dev/null for the same reason as Ocr.qml's run(): slurp
        // otherwise waits on Process's never-closed stdin pipe and never draws.
        _qrSlurp.command = ["sh", "-c", 'exec slurp "$@" </dev/null', "slurp", "-d", "-w", "2",
            "-b", root._hex(Colors.surface) + "b3",
            "-s", "#00000000",
            "-c", root._hex(Colors.accent) + "ff"];
        _qrSlurp.running = true;
    }

    function _hex(c) {
        const h = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
        return `#${h(c.r)}${h(c.g)}${h(c.b)}`;
    }

    property string _qrImgPath: ""

    Process {
        id: _qrSlurp
        command: ["slurp"]
        property string _out: ""
        stdout: StdioCollector { onStreamFinished: _qrSlurp._out = this.text }
        onExited: (exitCode, exitStatus) => {
            const geo = _qrSlurp._out.trim();
            if (exitCode !== 0 || !geo) {
                // Cancelled -- same quiet "back to idle, reopened" rule OCR
                // follows above.
                root.activeTool = "";
                root.panelOpen = true;
                return;
            }
            const dir = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
            root._qrImgPath = `${dir}/rd-shell-qr-${Date.now()}.png`;
            _qrGrim.command = ["grim", "-g", geo, root._qrImgPath];
            _qrGrim.running = true;
        }
    }

    Process {
        id: _qrGrim
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.state = "error";
                root.errorText = "capture failed";
                root.panelOpen = true;
                return;
            }
            _zbar.command = ["zbarimg", "--raw", "-q", root._qrImgPath];
            _zbar.running = true;
        }
    }

    Process {
        id: _zbar
        property string _out: ""
        stdout: StdioCollector { onStreamFinished: _zbar._out = this.text }
        onExited: (exitCode, exitStatus) => {
            Quickshell.execDetached(["rm", "-f", root._qrImgPath]);
            const out = _zbar._out.trim();
            // zbarimg exits non-zero (4, per its own docs) for "scanned,
            // found nothing" -- not an error, just the "nothing found"
            // state the brief asks for.
            if (exitCode !== 0 || !out) {
                root.state = "empty";
                root.panelOpen = true;
                return;
            }
            root.resultText = out;
            root.state = "done";
            Quickshell.execDetached(["wl-copy", out]);
            root.panelOpen = true;
        }
    }

    // ── colour pick: hyprpicker is its own selector, no slurp ───
    // The "mechanism" color-picker-hyprpicker-in-shell is told to reuse: run
    // hyprpicker with -a (autocopy, so wl-copy never has to be called
    // separately), -b (no ANSI colour codes mixed into stdout), -l
    // (lowercase hex, matching the swatch label's own case) and a fixed
    // output format so stdout is exactly "#rrggbb" and nothing else.
    function startColor() {
        if (!root.colorAvailable || root.activeTool !== "") return;
        root.activeTool = "color";
        root.state = "";
        root.panelOpen = false;
        _hyprpicker.running = true;
    }

    Process {
        id: _hyprpicker
        command: ["hyprpicker", "-a", "-b", "-l", "-f", "hex"]
        property string _out: ""
        stdout: StdioCollector { onStreamFinished: _hyprpicker._out = this.text }
        onExited: (exitCode, exitStatus) => {
            const out = _hyprpicker._out.trim();
            // Escape (or any other cancel) leaves hyprpicker with nothing on
            // stdout -- same quiet-cancel rule slurp follows above.
            if (exitCode !== 0 || !/^#[0-9a-f]{6}$/.test(out)) {
                root.activeTool = "";
                root.panelOpen = true;
                return;
            }
            root.resultColor = out;
            root.state = "done";
            root.panelOpen = true;
        }
    }
}
