pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Per-monitor brightness and contrast over DDC/CI, for the desktop displays
// Services/Brightness.qml cannot reach through a backlight device -- see the
// comment there. `ddcutil detect --brief` maps a Quickshell screen name (the
// DRM connector, with the "cardN-" prefix ddcutil prints stripped off) to the
// display number every later call addresses it by.
//
// The one fact that shapes everything below: a `ddcutil` call is a few
// hundred milliseconds of talking to a real i2c bus, and two of them at once
// on the same bus step on each other. So this singleton runs exactly one
// `ddcutil` process at a time through a small job queue (`_queue`), and a
// slider's setBrightness/setContrast calls -- which can arrive many times a
// second during a drag -- are coalesced by a debounce Timer that keeps only
// the latest percent per (screen, VCP code) and never even enqueues the ones
// it replaces.
Singleton {
    id: root

    readonly property bool ready: root._ready
    property bool _ready: false

    // screenName -> ddcutil display number, filled once by detect().
    property var _displays: ({})

    // screenName -> { brightness, contrast, maxBrightness, maxContrast }.
    // brightness/contrast are already scaled to 0..100 and start at -1 ("not
    // yet read"); the max fields are raw VCP maxima, learned from the first
    // getvcp for that property and assumed 100 -- true on both displays here
    // -- until then, since a write has to go out in raw units and cannot
    // wait on a read that has not come back yet.
    property var _state: ({})

    signal changed(string screenName)

    function has(screenName) {
        return root._displays[screenName] !== undefined;
    }

    function brightness(screenName) {
        const s = root._state[screenName];
        return s ? s.brightness : -1;
    }

    function contrast(screenName) {
        const s = root._state[screenName];
        return s ? s.contrast : -1;
    }

    function setBrightness(screenName, percent) {
        root._request(screenName, 10, percent);
    }

    function setContrast(screenName, percent) {
        root._request(screenName, 12, percent);
    }

    function _stateFor(screenName) {
        let s = root._state[screenName];
        if (!s) {
            s = { brightness: -1, contrast: -1, maxBrightness: 100, maxContrast: 100 };
            root._state[screenName] = s;
        }
        return s;
    }

    // Coalesced write requests, keyed "screenName:vcp" -> latest percent.
    // Flushed into the job queue only once the debounce below goes quiet,
    // which is what turns a continuous drag into a single ddcutil call
    // instead of one per frame.
    property var _pending: ({})
    property var _queue: []
    property var _running: null

    function _request(screenName, vcp, percent) {
        if (!root.has(screenName)) return;

        const clamped = Math.max(0, Math.min(100, Math.round(percent)));

        // Optimistic: the cache -- and anything bound to it -- moves with the
        // pointer immediately. The hardware catches up behind it once the
        // debounce below fires; nothing here waits on that to happen.
        const s = root._stateFor(screenName);
        if (vcp === 10) s.brightness = clamped; else s.contrast = clamped;
        root.changed(screenName);

        root._pending[screenName + ":" + vcp] = clamped;
        debounce.restart();
    }

    Timer {
        id: debounce
        // Long enough that a drag's many calls per second collapse into one
        // write, short enough that letting go of the slider reads as "it
        // answered" rather than "it thought about it".
        interval: 100
        onTriggered: root._flushPending()
    }

    function _flushPending() {
        for (const key in root._pending) {
            const sep = key.lastIndexOf(":");
            root._queue.push({
                kind: "write",
                screenName: key.slice(0, sep),
                vcp: parseInt(key.slice(sep + 1)),
                percent: root._pending[key]
            });
        }
        root._pending = {};
        root._pump();
    }

    function _pump() {
        if (root._running || root._queue.length === 0) return;

        const job = root._queue.shift();
        const num = root._displays[job.screenName];
        if (num === undefined) { root._pump(); return; }

        root._running = job;

        if (job.kind === "read") {
            proc.command = ["ddcutil", "-d", String(num), "getvcp", String(job.vcp), "--brief"];
        } else {
            const s = root._stateFor(job.screenName);
            const max = job.vcp === 10 ? s.maxBrightness : s.maxContrast;
            const raw = Math.max(0, Math.min(max, Math.round(job.percent / 100 * max)));
            proc.command = ["ddcutil", "-d", String(num), "setvcp", String(job.vcp), String(raw)];
        }

        proc.running = true;
    }

    // The one and only ddcutil process in flight at any time -- read jobs
    // (the startup priming sweep) and write jobs (coalesced slider moves)
    // share it, so serialization is automatic rather than something each
    // caller has to remember to respect.
    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                const job = root._running;
                root._running = null;
                proc.running = false;

                // A transient failure (monitor asleep, bus busy) prints
                // nothing usable here and stderr is not even collected: the
                // cache keeps whatever it already had -- the optimistic
                // value for a write, the previous read for a read -- and the
                // next interaction is a fresh attempt, not a retry loop.
                if (job && job.kind === "read") root._acceptRead(job, this.text);

                root._pump();
            }
        }
    }

    function _acceptRead(job, text) {
        const m = text.match(/VCP\s+\S+\s+\S+\s+(\d+)\s+(\d+)/);
        if (!m) return;

        const cur = parseInt(m[1]);
        const max = parseInt(m[2]);
        if (!(max > 0)) return;

        const s = root._stateFor(job.screenName);
        const pct = Math.round(cur / max * 100);
        if (job.vcp === 10) { s.maxBrightness = max; s.brightness = pct; }
        else { s.maxContrast = max; s.contrast = pct; }

        root.changed(job.screenName);
    }

    Component.onCompleted: detect.running = true

    // Runs once at startup. Detection itself takes a noticeable moment (this
    // is still `ddcutil` talking to i2c under the hood), so nothing here
    // blocks on it -- `ready` and `has()` simply stay at their empty
    // defaults until this returns.
    Process {
        id: detect
        command: ["ddcutil", "detect", "--brief"]

        stdout: StdioCollector {
            onStreamFinished: root._acceptDetect(this.text)
        }
    }

    // `ddcutil detect --brief` still prints one block per display, e.g.:
    //   Display 1
    //      I2C bus:          /dev/i2c-3
    //      DRM connector:    card1-DP-1
    // so a display's number comes from its own "Display N" line and is
    // paired with the very next "DRM connector:" line in the same block.
    function _acceptDetect(text) {
        const map = {};
        let num = null;

        for (const line of text.split("\n")) {
            const dm = line.match(/^Display (\d+)/);
            if (dm) { num = parseInt(dm[1]); continue; }

            const cm = line.match(/DRM connector:\s*(\S+)/);
            if (cm && num !== null) {
                map[cm[1].replace(/^card\d+-/, "")] = num;
                num = null;
            }
        }

        root._displays = map;
        root._ready = Object.keys(map).length > 0;

        // Prime every display's brightness and contrast once, in the
        // background, so brightness()/contrast() turn into real numbers on
        // their own instead of staying at -1 until something happens to ask
        // for a read first.
        for (const screenName in map) {
            root._queue.push({ kind: "read", screenName, vcp: 10 });
            root._queue.push({ kind: "read", screenName, vcp: 12 });
        }
        root._pump();
    }
}
