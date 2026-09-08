pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// CPU, memory and both GPUs, re-read from scripts/sysmon.sh on a timer.
//
// The script prints /proc's cumulative jiffy counters untouched; turning them
// into a percentage needs two samples, and holding the previous one here is
// both cheaper and truer than making the script sleep for a second reading.
Singleton {
    id: root

    // ── cpu ──────────────────────────────────────────────────
    // -1 until two samples exist, so a pill can stay quiet rather than claim
    // for one frame that a busy machine is idle.
    property real cpuPercent: -1
    property var cores: []
    property real cpuTemp: -1
    property real cpuMhz: 0
    property string cpuModel: ""

    // ── memory ───────────────────────────────────────────────
    property real memTotal: 0
    property real memUsed: 0
    property real memAvail: 0
    property real memCached: 0
    property real swapTotal: 0
    property real swapUsed: 0

    readonly property int memPercent: root.memTotal > 0
        ? Math.round(root.memUsed / root.memTotal * 100)
        : -1
    readonly property int swapPercent: root.swapTotal > 0
        ? Math.round(root.swapUsed / root.swapTotal * 100)
        : 0

    // ── gpu ──────────────────────────────────────────────────
    // The discrete card, read through nvidia-settings. It answers with a
    // temperature and its VRAM but not with utilisation, which lives in NVML
    // and so in nvidia-smi -- a binary this driver package does not install.
    property string gpuName: ""
    property string gpuDriver: ""
    property real gpuTemp: -1
    property real gpuFan: -1
    property real gpuMemUsed: 0
    property real gpuMemTotal: 0

    readonly property int gpuMemPercent: root.gpuMemTotal > 0
        ? Math.round(root.gpuMemUsed / root.gpuMemTotal * 100)
        : -1

    // The integrated Radeon, read from hwmon. It gives up the one number the
    // discrete card withholds -- how busy it is -- so both are shown rather
    // than one being picked as "the" GPU.
    property real igpuTemp: -1
    property real igpuBusy: -1
    property real igpuPower: -1

    // ── machine ──────────────────────────────────────────────
    property real uptime: 0
    property var load: [0, 0, 0]
    property string procCount: ""

    // ── processes ────────────────────────────────────────────
    // Only read while the popup is open: the sampler runs top twice half a
    // second apart, which is a fifth of a second of a core each time.
    property var topCpu: []
    property var topMem: []

    // Temperatures worth a colour change. AMD reports Tctl, which runs some ten
    // degrees above the die under load and is what the fan curve is built on,
    // so the warm step sits high; the discrete card throttles in the mid-
    // eighties and is given the same headroom.
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
        if (root.panelOpen) {
            root.refresh();
            root.refreshProcesses();
        }
    }

    function refresh() {
        query.running = true;
    }

    function refreshProcesses() {
        procQuery.running = true;
    }

    // SIGTERM by default -- a process asked to leave closes its files and saves
    // what it was holding. force is SIGKILL, which is offered separately in the
    // popup because it is a different promise: the process stops here, and
    // whatever it had not written is gone.
    function kill(pid, force) {
        Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM", String(pid)]);
        settle.restart();
    }

    function _parse(text) {
        let d;
        try {
            d = JSON.parse(text);
        } catch (e) {
            return;
        }

        // Index 0 is the whole-machine line, the rest are the cores in order.
        const prev = root._prevCpu;
        if (prev && prev.length === d.cpu.length) {
            const percents = d.cpu.map((now, i) => {
                const total = now[0] - prev[i][0];
                const idle = now[1] - prev[i][1];
                // A counter that did not move means an offline core, not a
                // fully loaded one.
                return total > 0
                    ? Math.max(0, Math.min(100, Math.round((1 - idle / total) * 100)))
                    : 0;
            });

            root.cpuPercent = percents[0];
            root.cores = percents.slice(1);
        }
        root._prevCpu = d.cpu;

        root.cpuTemp = d.cpuTemp ?? -1;
        root.cpuMhz = d.cpuMhz ?? 0;

        root.memTotal = d.memTotal;
        // Used is what is gone, not what is allocated: MemAvailable already
        // discounts the cache the kernel would hand back under pressure, which
        // is why this number stays sane on a machine with 18G of page cache.
        root.memUsed = d.memTotal - d.memAvail;
        root.memAvail = d.memAvail;
        root.memCached = d.cached;
        root.swapTotal = d.swapTotal;
        root.swapUsed = d.swapUsed;

        root.gpuTemp = d.gpuTemp ?? -1;
        root.gpuMemUsed = d.gpuMemUsed ?? 0;
        root.gpuMemTotal = d.gpuMemTotal ?? 0;
        root.gpuFan = d.gpuFan ?? -1;

        root.igpuTemp = d.igpuTemp ?? -1;
        root.igpuBusy = d.igpuBusy ?? -1;
        root.igpuPower = d.igpuPower ?? -1;

        root.uptime = d.uptime;
        root.load = d.load;
        // "3/1568" from loadavg: running of total.
        root.procCount = (d.procs ?? "").split("/")[1] ?? "";
    }

    function _parseProcesses(text) {
        try {
            const d = JSON.parse(text);
            root.topCpu = d.cpu;
            root.topMem = d.mem;
        } catch (e) {
        }
    }

    property var _prevCpu: null

    // Fast until the second sample lands, since the first one only primes the
    // delta and every percentage in the popup is blank until then.
    Timer {
        interval: root.cpuPercent < 0 ? 700 : 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // A signal is delivered long before the process it named is reaped, so the
    // list is re-read once the kernel has had time to do it.
    Timer {
        id: settle
        interval: 500
        onTriggered: root.refreshProcesses()
    }

    Process {
        id: query
        command: ["sh", Quickshell.shellPath("scripts/sysmon.sh")]
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    Process {
        id: procQuery
        command: ["sh", Quickshell.shellPath("scripts/sysmon-procs.sh")]
        stdout: StdioCollector {
            onStreamFinished: root._parseProcesses(this.text)
        }
    }

    // What this machine is, read once: three strings that never change while
    // the shell runs, and so have no business in the two-second poll.
    Process {
        running: true
        command: ["sh", "-c",
            "sed -n 's/^model name[^:]*: //p' /proc/cpuinfo | head -1;"
            + " cat /proc/driver/nvidia/gpus/*/information 2>/dev/null"
            + " | sed -n 's/^Model:[^A-Za-z]*//p' | head -1;"
            + " awk '/Kernel Module/ { for (i = 1; i <= NF; i++)"
            + " if ($i ~ /^[0-9]+[.][0-9]+/) { print $i; exit } }'"
            + " /proc/driver/nvidia/version 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").map(l => l.trim());
                // Marketing suffixes only push the interesting part out of the
                // card: nobody needs to be told a Ryzen has a processor, or
                // that an NVIDIA card was made by NVIDIA.
                root.cpuModel = (lines[0] ?? "").replace(/\s*\d+-Core Processor\s*/, "");
                root.gpuName = (lines[1] ?? "").replace(/^NVIDIA /, "");
                root.gpuDriver = lines[2] ?? "";
            }
        }
    }
}
