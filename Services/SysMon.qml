pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// CPU, memory and both GPUs, fed by one long-running scripts/sysmon.py that
// replaces sysmon.sh + sysmon-procs.sh + nvidia-settings.
//
// Percentages arrive ready-made rather than as raw counters: the sampler
// keeps its own previous /proc/stat sample between ticks (a long-running
// process can hold that state for free), so this file only ever has to
// assign what a line handed it, never diff two of them itself the way the
// short-lived sysmon.sh forced the old version of this file to.
Singleton {
    id: root

    // Two minutes of history at the tick rate below, for the area graphs.
    readonly property int historyLength: 60

    // ── cpu ──────────────────────────────────────────────────
    // -1 until the sampler's first line lands (it needs two /proc/stat reads
    // itself before that), so a pill can stay quiet rather than claim for
    // one frame that a busy machine is idle.
    property real cpuPercent: -1
    property var cores: []
    property var coreMhz: []
    property real cpuTemp: -1
    property real cpuMhz: 0
    property string cpuModel: ""
    property real iowait: -1
    property int running: 0
    property string procCount: ""

    // ── memory ───────────────────────────────────────────────
    property real memTotal: 0
    property real memUsed: 0
    property real memAvail: 0
    property real memFree: 0
    property real memCached: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property real zramOrig: 0
    property real zramCompr: 0
    property real zramRatio: 0

    readonly property int memPercent: root.memTotal > 0
        ? Math.round(root.memUsed / root.memTotal * 100)
        : -1
    readonly property int swapPercent: root.swapTotal > 0
        ? Math.round(root.swapUsed / root.swapTotal * 100)
        : 0

    // ── gpu (nvidia, via NVML in the sampler) ───────────────────
    property string gpuName: ""
    property string gpuDriver: ""
    property real gpuTemp: -1
    property real gpuFan: -1
    property real gpuFanPercent: -1
    property real gpuMemUsed: 0
    property real gpuMemTotal: 0
    property real gpuUtil: -1
    property real gpuMemUtil: -1
    property real gpuClock: -1
    property real gpuMemClock: -1
    property real gpuPower: -1
    property real gpuPowerLimit: -1
    property int gpuPstate: -1
    property real gpuEnc: -1
    property real gpuDec: -1

    readonly property int gpuMemPercent: root.gpuMemTotal > 0
        ? Math.round(root.gpuMemUsed / root.gpuMemTotal * 100)
        : -1

    // The integrated Radeon, read from hwmon -- it gives up the one number
    // the discrete card does not report through NVML on this box (busy%),
    // so both are shown rather than one being picked as "the" GPU.
    property real igpuTemp: -1
    property real igpuBusy: -1
    property real igpuPower: -1

    // ── machine ──────────────────────────────────────────────
    property real uptime: 0
    property var load: [0, 0, 0]

    // ── history ──────────────────────────────────────────────
    // Plain JS arrays of numbers, oldest first, reassigned (never mutated)
    // every tick -- so a chart bound straight to one of these repaints on
    // its own change notification instead of needing to be told to.
    property var cpuHistory: []
    property var gpuHistory: []
    property var memHistory: []

    // ── processes ────────────────────────────────────────────
    // Reassigned each scan -- app-level groups, heaviest pid first within a
    // group. Sorting and trimming to a row count is the list's job
    // (SysProcList.qml), since each tab sorts by a different key.
    property var processes: []

    // Temperatures worth a colour change. AMD reports Tctl, which runs some
    // ten degrees above the die under load and is what the fan curve is
    // built on, so the warm step sits high; the discrete card throttles in
    // the mid-eighties and is given the same headroom.
    readonly property int cpuWarm: 75
    readonly property int cpuHot: 90
    readonly property int gpuWarm: 70
    readonly property int gpuHot: 84

    // One sample is enough for a temperature, so the pills light up on the
    // first tick and only the percentages wait for the second.
    readonly property bool available: root.cpuTemp >= 0

    // Open state for the popup. On the service rather than on a pill because
    // three pills open the same card and a keybind opens it without any of
    // them: what is per-bar is only which icon it points at.
    property bool panelOpen: false

    function togglePanel() {
        root.panelOpen = !root.panelOpen;
    }

    // Per-process scanning is the one thing here with a real CPU cost, so
    // the sampler only pays it while a popup is actually open to show it --
    // driven off panelOpen directly rather than only from togglePanel(),
    // because BarOverlays also closes the panel by assigning the property
    // straight (dismiss-on-click-outside).
    // The rows are dropped on open rather than on close: the sampler stops
    // sending them while closed, so whatever is left is from the last visit
    // (dead pids, old numbers) and the list should show "sampling" instead --
    // but clearing on close would empty the list under its closing fade.
    onPanelOpenChanged: {
        if (root.panelOpen) root.processes = [];
        root._send(root.panelOpen ? "procs on" : "procs off");
    }

    // SIGTERM by default -- a process asked to leave closes its files and
    // saves what it was holding. force is SIGKILL, offered separately in the
    // popup because it is a different promise: the process stops here, and
    // whatever it had not written is gone. `pids` is every pid in the
    // group's row, so ending an app with several processes takes one click.
    function kill(pids, force) {
        for (const pid of pids)
            Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM", String(pid)]);
        settle.restart();
    }

    function _send(line) {
        if (sampler.running) sampler.write(line + "\n");
    }

    function _push(arr, value) {
        const a = arr.slice();
        a.push(value);
        if (a.length > root.historyLength) a.splice(0, a.length - root.historyLength);
        return a;
    }

    function _parse(text) {
        let d;
        try {
            d = JSON.parse(text);
        } catch (e) {
            return;
        }

        root.cpuPercent = d.cpuPercent ?? -1;
        root.cores = d.cores ?? [];
        root.coreMhz = d.coreMhz ?? [];
        root.cpuTemp = d.cpuTemp ?? -1;
        root.cpuMhz = d.cpuMhz ?? 0;
        root.cpuModel = d.cpuModel ?? "";
        root.iowait = d.iowait ?? -1;
        root.running = d.running ?? 0;
        // Old wire shape kept exactly ("running/total" from /proc/loadavg),
        // so `procCount` keeps meaning exactly what it always meant: the
        // total alone, a string, not the pair.
        root.procCount = (d.procs ?? "").split("/")[1] ?? "";

        root.memTotal = d.memTotal ?? 0;
        root.memAvail = d.memAvail ?? 0;
        root.memFree = d.memFree ?? 0;
        // Used is what is gone, not what is allocated: MemAvailable already
        // discounts the cache the kernel would hand back under pressure.
        root.memUsed = root.memTotal - root.memAvail;
        root.memCached = d.cached ?? 0;
        root.swapTotal = d.swapTotal ?? 0;
        root.swapUsed = d.swapUsed ?? 0;
        root.zramOrig = d.zramOrig ?? 0;
        root.zramCompr = d.zramCompr ?? 0;
        root.zramRatio = d.zramRatio ?? 0;

        root.gpuName = d.gpuName ?? "";
        root.gpuDriver = d.gpuDriver ?? "";
        root.gpuTemp = d.gpuTemp ?? -1;
        root.gpuFan = d.gpuFan ?? -1;
        root.gpuFanPercent = d.gpuFanPercent ?? -1;
        root.gpuMemUsed = d.gpuMemUsed ?? 0;
        root.gpuMemTotal = d.gpuMemTotal ?? 0;
        root.gpuUtil = d.gpuUtil ?? -1;
        root.gpuMemUtil = d.gpuMemUtil ?? -1;
        root.gpuClock = d.gpuClock ?? -1;
        root.gpuMemClock = d.gpuMemClock ?? -1;
        root.gpuPower = d.gpuPower ?? -1;
        root.gpuPowerLimit = d.gpuPowerLimit ?? -1;
        root.gpuPstate = d.gpuPstate ?? -1;
        root.gpuEnc = d.gpuEnc ?? -1;
        root.gpuDec = d.gpuDec ?? -1;

        root.igpuTemp = d.igpuTemp ?? -1;
        root.igpuBusy = d.igpuBusy ?? -1;
        root.igpuPower = d.igpuPower ?? -1;

        root.uptime = d.uptime ?? 0;
        root.load = d.load ?? [0, 0, 0];

        // Sampled every tick, open or closed -- unknown reads as 0 here
        // rather than -1, since a history chart has no sane way to plot "no
        // data" as a negative bar.
        root.cpuHistory = root._push(root.cpuHistory, Math.max(0, root.cpuPercent));
        root.gpuHistory = root._push(root.gpuHistory, Math.max(0, root.gpuUtil));
        root.memHistory = root._push(root.memHistory, Math.max(0, root.memPercent));

        if (d.processes) root.processes = d.processes;
    }

    // Backoff for the restart timer below, doubled on every crash inside the
    // first 5s of a run (a crash loop -- missing python3, a syntax error
    // reintroduced by a bad edit) and reset back to 1s once a run has stood
    // up for longer than that (a one-off kill, not a loop).
    property int _backoff: 1000
    property real _startedAt: 0

    Timer {
        id: restartTimer
        onTriggered: sampler.running = true
    }

    Process {
        id: sampler
        running: true
        stdinEnabled: true
        command: ["python3", Quickshell.shellPath("scripts/sysmon.py")]

        onRunningChanged: if (sampler.running) {
            root._startedAt = Date.now();
            // A popup already open across a restart (the sampler crashed
            // while shown) needs to be told again -- the fresh process
            // starts with per-process scanning off.
            if (root.panelOpen) root._send("procs on");
        }

        onExited: (exitCode, exitStatus) => {
            if (Date.now() - root._startedAt > 5000) root._backoff = 1000;
            restartTimer.interval = root._backoff;
            root._backoff = Math.min(root._backoff * 2, 30000);
            restartTimer.start();
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._parse(data)
        }
    }

    // A signal is delivered long before the process it named is reaped, so
    // the sampler is asked for a fresh scan once the kernel has had time to
    // do it -- this is what makes a kill drop the row without waiting out
    // the rest of the normal 2s tick.
    Timer {
        id: settle
        interval: 500
        onTriggered: root._send("scan")
    }
}
