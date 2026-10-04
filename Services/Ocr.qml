pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.Config

// Region OCR: slurp a selection, `grim -g` it to a temp PNG under
// $XDG_RUNTIME_DIR, feed that to `tesseract <img> -` for plain text on
// stdout, then delete the temp file. No translation step -- see idea
// screen-region-ocr-translate-popup for that distinct case; this file is
// deliberately just the capture+recognise pipeline underneath it, so that
// idea (and in-shell-utility-tray-ocr-colorpicker-qr's own "Read text" entry,
// which drives this directly too -- see Services/Utilities.qml) share one
// implementation instead of two.
Singleton {
    id: root

    // Re-checked by whoever is about to show a tesseract-gated control --
    // Services/Utilities.qml calls checkAvailable() on every tray open, per
    // the brief ("detect binaries each time the popup opens"), since
    // installing tesseract mid-session has to flip this with no restart.
    // Starts true so a cold shell never flashes "disabled" before the first
    // check lands -- `command -v` resolves in well under a frame.
    property bool available: true

    // "" idle/cancelled, "capturing" (slurp/grim in flight), "recognizing"
    // (tesseract running), "done", "empty" (nothing recognised), "error".
    property string state: ""
    property string text: ""
    property string error: ""

    function checkAvailable() {
        if (!_check.running)
            _check.running = true;
    }

    Process {
        id: _check
        command: ["sh", "-c", "command -v tesseract >/dev/null 2>&1 && echo 1 || echo 0"]
        property string _out: ""
        stdout: StdioCollector { onStreamFinished: _check._out = this.text }
        onExited: root.available = _check._out.trim() === "1"
    }

    // One run at a time -- a second region-select on top of a slurp that is
    // already up would only fight it for the pointer, the same "one in
    // flight is enough" rule DiscordCall.qml's vesktop lookup follows.
    function run() {
        if (root.state === "capturing" || root.state === "recognizing") return;
        root.state = "capturing";
        root.text = "";
        root.error = "";
        // Themed the same way scripts/screenshot.sh themes its own slurp --
        // dim everything outside the selection in the surface colour, leave
        // the selection itself clear, outline it in the live accent -- so
        // the moment the tray hides there is an unmissable on-screen cue
        // that a region grab is in progress, not just a crosshair cursor.
        // No freeze layer here (unlike the screenshot script): grim only
        // runs after slurp exits, so there is no baked-in-cursor risk to
        // guard against, and skipping it keeps this pipeline to one process
        // instead of two.
        // stdin from /dev/null, through sh: slurp treats a non-TTY stdin as a
        // list of predefined boxes and reads it to EOF before it draws
        // anything, and Process hands it a pipe that never closes -- so a bare
        // ["slurp", ...] sits in a pipe read with no overlay on screen, which
        // is exactly "clicked it and nothing happened".
        _slurp.command = ["sh", "-c", 'exec slurp "$@" </dev/null', "slurp", "-d", "-w", "2",
            "-b", root._hex(Colors.surface) + "b3",
            "-s", "#00000000",
            "-c", root._hex(Colors.accent) + "ff"];
        _slurp.running = true;
    }

    function _hex(c) {
        const h = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
        return `#${h(c.r)}${h(c.g)}${h(c.b)}`;
    }

    function reset() {
        root.state = "";
        root.text = "";
        root.error = "";
    }

    property string _imgPath: ""

    Process {
        id: _slurp
        command: ["slurp"]
        property string _out: ""
        stdout: StdioCollector { onStreamFinished: _slurp._out = this.text }
        onExited: (exitCode, exitStatus) => {
            const geo = _slurp._out.trim();
            // Esc, or any other way slurp leaves without a region, exits
            // non-zero with empty stdout -- a cancel, not an error, so this
            // goes back to idle quietly rather than surfacing anything.
            if (exitCode !== 0 || !geo) {
                root.state = "";
                return;
            }
            const dir = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
            root._imgPath = `${dir}/rd-shell-ocr-${Date.now()}.png`;
            _grim.command = ["grim", "-g", geo, root._imgPath];
            _grim.running = true;
        }
    }

    Process {
        id: _grim
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.state = "error";
                root.error = "capture failed";
                return;
            }
            root.state = "recognizing";
            _tesseract.command = ["tesseract", root._imgPath, "-"];
            _tesseract.running = true;
        }
    }

    Process {
        id: _tesseract
        property string _out: ""
        stdout: StdioCollector { onStreamFinished: _tesseract._out = this.text }
        onExited: (exitCode, exitStatus) => {
            // Best-effort cleanup -- a failed rm here leaves one stray PNG
            // in a tmpfs that is wiped on logout anyway, not a reason to
            // surface a second error on top of whatever tesseract just did.
            Quickshell.execDetached(["rm", "-f", root._imgPath]);
            const out = _tesseract._out.trim();
            if (exitCode !== 0 || !out) {
                root.state = "empty";
                return;
            }
            root.text = out;
            root.state = "done";
        }
    }
}
