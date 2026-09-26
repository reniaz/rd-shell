pragma Singleton
import Quickshell
import Quickshell.Io
import QtQml.Models
import QtQuick

// Caps Lock / Num Lock, OR'd across however many input devices this box
// currently has a LED for -- two right now (input2, input16), and a USB
// keyboard being plugged in or unplugged changes that set at runtime. Fed
// from /sys/class/leds/*::capslock(/numlock)/brightness, the same kernel LED
// class Services/Brightness.qml already reads for the backlight case, so
// nothing here asks Hyprland or xset anything.
//
// `watchChanges` below is left on because it costs nothing, but this does
// not lean on it working: these files are 644 root:root (this user is in
// `input`, not a group that can write them), so there is no way on this
// machine to flip one without a real keypress and check whether Qt's
// watcher backend -- inotify under the hood -- actually fires for a sysfs
// attribute write. It may well not; sysfs attributes are documented to
// answer `poll()` with `POLLPRI` on a value change, which is a different
// mechanism than the rename/create events inotify watches for. The reload
// timer below is what this singleton actually depends on either way, and it
// costs one stat+read per known device per tick -- FileView.reload() is a
// file read, never a process -- not a process spawned on any cadence.
Singleton {
    id: root

    property bool capsOn: false
    property bool numOn: false

    // Which one last flipped, and its new state -- what LockKeysOsd.qml
    // flashes. Not derived from capsOn/numOn alone: both are booleans with
    // no memory of which just changed, and a change handler is the natural
    // place to also say "this one".
    property string mode: "caps"

    property bool _capsAnnounced: false
    property bool _numAnnounced: false

    // path -> last-read boolean. Plain JS objects, not Qt properties -- kept
    // only so _recompute() has something to OR across; nothing binds to
    // these directly, which is exactly why they need not be properties.
    property var _caps: ({})
    property var _num: ({})

    // {path, kind} for every capslock/numlock LED currently under
    // /sys/class/leds. Handed to the Instantiator below, which is what
    // actually creates or drops a FileView as a device appears or leaves.
    property var _devices: []

    function _recompute() {
        root.capsOn = Object.values(root._caps).some(v => v);
        root.numOn = Object.values(root._num).some(v => v);
    }

    function _rescan(text) {
        const names = text.split("\n").map(l => l.trim()).filter(l => l !== "");
        const next = names.map(n => ({
            path: `/sys/class/leds/${n}/brightness`,
            kind: n.endsWith("::capslock") ? "caps" : "num",
        }));

        // Same "did the set actually change" guard as Services/Workspaces.
        // qml's dotsFor(): handing the Instantiator a materially identical
        // array on every rescan would tear down and rebuild every FileView
        // -- and re-read every brightness -- on a 10s timer for no reason.
        const prevKey = root._devices.map(d => d.path).sort().join("|");
        const nextKey = next.map(d => d.path).sort().join("|");
        if (prevKey === nextKey) return;

        // Drop cached state for whatever just left, so an unplugged
        // keyboard's last-known "on" cannot keep the OR stuck lit forever.
        for (const p of Object.keys(root._caps)) if (!next.some(d => d.path === p)) delete root._caps[p];
        for (const p of Object.keys(root._num)) if (!next.some(d => d.path === p)) delete root._num[p];

        // Re-arm both first-read guards. The model change below tears down
        // and rebuilds every FileView, persisting devices included -- plain
        // JS array models have no per-row identity for Instantiator to diff
        // against, so this is a full rebuild, not just an add/remove of the
        // device that actually changed. Every one of those rebuilt FileViews
        // fires onLoaded again as if for the first time, and without this,
        // a hot-plugged keyboard whose LED already differs from the current
        // OR'd state would read as a real toggle nobody performed -- exactly
        // the spurious flash `_capsAnnounced`/`_numAnnounced` exist to
        // prevent at startup, replayed on every later device-set change too.
        root._capsAnnounced = false;
        root._numAnnounced = false;

        root._devices = next;
        root._recompute();
    }

    Process {
        id: scan
        command: ["sh", "-c", "ls -1 /sys/class/leds/ 2>/dev/null | grep -E '::capslock$|::numlock$'"]
        stdout: StdioCollector {
            onStreamFinished: root._rescan(this.text)
        }
    }

    Component.onCompleted: scan.running = true

    // Devices essentially never appear or disappear outside a keyboard being
    // plugged in, so 10s is generous rather than tight -- one `ls`+`grep` at
    // that rate costs nothing. `reloadTimer` below is the one that actually
    // has to stay light, since it fires far more often.
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: scan.running = true
    }

    // The reason this file polls at all instead of trusting `watchChanges`
    // alone -- see the header comment. `objectAt`/`count` are Instantiator's
    // own (QtQml.Models), not Repeater's.
    Timer {
        id: reloadTimer
        interval: 400
        running: root._devices.length > 0
        repeat: true
        onTriggered: {
            for (let i = 0; i < watchers.count; i++) {
                const fv = watchers.objectAt(i);
                if (fv) fv.reload();
            }
        }
    }

    Instantiator {
        id: watchers
        model: root._devices

        delegate: FileView {
            required property var modelData

            path: modelData.path
            watchChanges: true
            printErrors: false

            onLoaded: {
                const on = (parseInt(text()) || 0) > 0;
                const bucket = modelData.kind === "caps" ? root._caps : root._num;
                if (bucket[path] === on) return;

                bucket[path] = on;

                const wasCaps = modelData.kind === "caps";
                const before = wasCaps ? root.capsOn : root.numOn;
                root._recompute();
                const after = wasCaps ? root.capsOn : root.numOn;
                if (after === before) return;

                const announced = wasCaps ? root._capsAnnounced : root._numAnnounced;
                if (!announced) {
                    if (wasCaps) root._capsAnnounced = true; else root._numAnnounced = true;
                    return;
                }

                root.mode = wasCaps ? "caps" : "num";
                root.osdVisible = true;
                osdHold.restart();
            }
            onFileChanged: reload()
        }
    }

    // Raised for one beat after a real toggle -- never for the state a
    // device already had when its watcher first opened, the same
    // first-read-is-not-a-change guard Services/Brightness.qml and
    // Services/KeyboardLayout.qml both use for their own OSD pulses.
    property bool osdVisible: false

    Timer {
        id: osdHold
        interval: 1200
        onTriggered: root.osdVisible = false
    }
}
