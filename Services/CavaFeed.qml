import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import qs.Config

// One cava process and the PipeWire links that decide what it hears.
// Services/Cava.qml owns the shared config and decides which streams each
// feed gets and when it should run; this file only turns that into a
// capture node fed exactly `streams`, and a `levels` array read from cava's
// 'raw' output mode on a pipe.
//
// cava is not pointed at the default sink's monitor. That monitor is the
// sink's finished mix, every other app's audio included, and no one stream
// can be taken back out of it. `proc` instead starts cava's capture stream
// with node.autoconnect=false, through PULSE_PROP -- pipewire-pulse copies
// the client's proplist onto its streams, checked with `pw-cli ls Node` --
// so WirePlumber does not link cava's *own* stream anywhere on its own. It
// still links other apps' streams into cava's input port the moment both
// exist, same as any other input -- autoconnect=false only opts cava's own
// stream out, not its ports out of being a valid target -- which is why
// `_stale` exists as well as `_unfed`: `_unfed` links every wanted stream
// into cava by hand; `_stale` unlinks anything else WirePlumber or a
// leftover link has fed in instead. PipeWire sums every link into an input
// port, so several streams still read as one mix.
//
// SIGTERM (what `wanted` going false sends) was confirmed to stop the
// process cleanly with no leftover state.
Scope {
    id: root

    // The capture node's node.name. Any other capture node named
    // `<nodeName>-<anything>` -- a terminal cava started with
    // PULSE_PROP='node.name=<nodeName>-<name> node.autoconnect=false' -- is
    // fed the same streams, so its spectrum matches this one.
    required property string nodeName
    required property string configPath
    required property int bars
    required property int framerate

    // Playback streams this feed's cava hears; anything else reaching its
    // node is unlinked again.
    property var streams: []

    // Whether cava should run at all. Raw mode is a continuous stream, and a
    // process left running with nothing to visualise keeps a high-refresh
    // compositor awake for no reason.
    property bool wanted: false
    property bool configReady: false

    // Latched on the first successful spawn rather than mirroring `running`:
    // a binary that has started once is installed for the rest of the
    // session. A missing binary never gets there -- Quickshell folds a
    // failed start back into `running` going false without it ever having
    // been true.
    property bool everRan: false

    readonly property bool active: root.wanted && proc.running

    property var levels: root._zeros()

    // 0..1, the smoothed mean of the current frame, so a consumer can read
    // "how loud is it right now" without knowing the bar count. Driven
    // imperatively by `_parse`, frame by frame.
    readonly property real level: root._level
    property real _level: 0

    // Frame-to-frame envelope coefficients for `level`, solved from the
    // first-order EMA settle formula -- (1 - a)^frames = 0.05, "reach 95% of
    // a step within this many frames at cava's own rate". Attack borrows
    // Motion.fast so a beat registers as a hit; decay borrows Motion.slow so
    // the reading coasts back down between hits instead of chattering.
    readonly property real _levelAttack: 1 - Math.pow(0.05, 1 / (root.framerate * Motion.fast / 1000))
    readonly property real _levelDecay: 1 - Math.pow(0.05, 1 / (root.framerate * Motion.slow / 1000))

    function _zeros() {
        const z = new Array(root.bars);
        z.fill(0);
        return z;
    }

    readonly property var _nodes: Pipewire.nodes.values.filter(n => {
        const name = n.name ?? "";
        return name === root.nodeName || name.startsWith(root.nodeName + "-");
    })

    // Every [stream, cava] pair still to be linked. Keyed off link groups
    // rather than the node list alone: a stream's ports arrive after its node
    // does and pw-link fails on a node with no ports yet, while a stream
    // WirePlumber has already linked somewhere certainly has them.
    readonly property var _unfed: {
        const groups = Pipewire.linkGroups.values;
        const streams = root.streams.filter(s => groups.some(g => g.source === s));
        const pairs = [];
        for (const cava of root._nodes)
            for (const s of streams)
                if (!groups.some(g => g.source === s && g.target === cava))
                    pairs.push([s, cava]);
        return pairs;
    }

    // Every [stream, cava] link that should not exist: something feeding one
    // of this feed's capture nodes that is not in `streams` right now.
    readonly property var _stale: {
        const groups = Pipewire.linkGroups.values;
        const pairs = [];
        for (const g of groups)
            if (root._nodes.includes(g.target) && !root.streams.includes(g.source))
                pairs.push([g.source, g.target]);
        return pairs;
    }

    // pw-link's links outlive pw-link itself, so a detached one-shot per pair
    // is all either takes. A repeat connect only fails "File exists", a
    // repeat disconnect only "No such link" -- both harmless.
    on_UnfedChanged: {
        for (const [s, cava] of root._unfed)
            Quickshell.execDetached(["pw-link", String(s.id), String(cava.id)]);
    }

    on_StaleChanged: {
        for (const [s, cava] of root._stale)
            Quickshell.execDetached(["pw-link", "-d", String(s.id), String(cava.id)]);
    }

    // Deliberately not a binding on `proc.running`: a failed spawn (cava
    // missing) makes Quickshell write `running` back to false from the C++
    // side, which would clear such a binding for good. Restating the desired
    // value on every real change has no such trap.
    function _sync() {
        proc.running = root.wanted && root.configReady;
    }

    onWantedChanged: root._sync()
    onConfigReadyChanged: root._sync()

    // Cleared rather than left at the last frame: a stale non-zero frame is
    // what a reader would see if it came back before the next real one, and
    // nothing drives `_parse` forward once the process stops.
    onActiveChanged: if (!root.active) {
        root.levels = root._zeros();
        root._level = 0;
    }

    Process {
        id: proc
        command: ["cava", "-p", root.configPath]
        environment: ({ PULSE_PROP: `node.name=${root.nodeName} node.autoconnect=false` })

        onRunningChanged: if (proc.running) root.everRan = true;
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._parse(data)
        }
    }

    function _parse(line) {
        const parts = line.split(";");
        // A well-formed frame is `bars` numbers each followed by ';',
        // including the last (see Services/Cava.qml), so it splits into
        // bars+1 parts. Anything shorter was handed over half-written and
        // would read as a flicker to zero.
        if (parts.length <= root.bars) return;

        const next = new Array(root.bars);
        let sum = 0;
        for (let i = 0; i < root.bars; i++) {
            const v = parseInt(parts[i], 10);
            const value = isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 100));
            next[i] = value;
            sum += value;
        }
        root.levels = next;

        const mean = sum / root.bars;
        const rate = mean > root._level ? root._levelAttack : root._levelDecay;
        root._level += (mean - root._level) * rate;
    }
}
