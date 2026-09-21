pragma Singleton
import Quickshell
import Quickshell.Io

// Which link is up, what it is called, and how much is moving over it.
//
// The link comes from NetworkManager, which is the only thing that knows the
// pretty name a connection was given. The throughput does not: nmcli has no
// rate to report, so it is read from the kernel's own byte counters under
// /sys/class/net. Those count upwards from the moment the interface appeared,
// so a speed is the difference between two of them over the time between them
// -- the same arithmetic SysMon does to /proc's jiffies, and for the same
// reason: the counter is the honest thing to publish, and the rate is a
// question asked of two of them.
Singleton {
    id: root

    // "ethernet", "wifi", or "" when nothing is up
    property string type: ""
    property string name: ""

    // The kernel's name for the same link -- enp12s0, wlp13s0. The connection
    // name is what a person calls it; this is what /sys calls it, and only one
    // of the two can be used to find a file.
    property string device: ""

    readonly property bool connected: type !== ""
    readonly property bool wired: type === "ethernet"

    // ── throughput ───────────────────────────────────────────
    // Bytes per second, and -1 until two samples exist to subtract. A rate of
    // zero is a claim that nothing is moving, which is a different statement
    // from "nobody has looked yet" -- and the popup must not be made to animate
    // a meter up from a zero that was never true.
    property real rxRate: -1
    property real txRate: -1

    // The counters themselves, which are bytes since the interface came up --
    // in practice since boot for the wired link this machine lives on.
    property real rxTotal: 0
    property real txTotal: 0

    readonly property bool sampled: root.rxRate >= 0

    // The last minute or so of rates, oldest first, one { rx, tx } per sample.
    // It lives here and not in the popup because the service outlives the
    // window: closing the card pauses the graph, and opening it again continues
    // the line rather than starting a fresh one from nothing.
    //
    // Sixty samples and not sixty seconds. While the popup is shut nothing is
    // sampled, so the history is a record of what was seen and not of a span of
    // time -- which is why the popup draws it without a time axis.
    property var history: []
    readonly property int historyMax: 60

    // The scale the popup draws everything against. One number for both
    // directions, so a 40M/s download and a 300K/s upload are seen to be
    // different sizes instead of each filling a bar of its own. Floored so that
    // an idle link draws as idle: against a true peak of a few hundred bytes, a
    // stray ARP reply would fill the meter.
    readonly property real peak: {
        let m = 65536;
        for (const s of root.history) m = Math.max(m, s.rx, s.tx);
        return m;
    }

    // plasma-nm's NetworkManager editor -- nm-connection-editor is not installed
    function openSettings() {
        Quickshell.execDetached(["kcmshell6", "kcm_networkmanagement"]);
    }

    // Read the counters once. Called on a timer by the popup for as long as it
    // is open and by nothing else: /sys costs a couple of milliseconds to read,
    // but a rate nobody is looking at is a timer running for no one.
    function sample() {
        if (root.device === "") return;
        counters.running = true;
    }

    // DEVICE, TYPE and STATE never contain ":", so the connection name is simply
    // everything after the first three fields. nmcli escapes ":" inside a name
    // as "\\:", which the rejoin preserves and the replace unescapes. DEVICE is
    // asked for first for exactly that reason: a fixed position ahead of the one
    // field that can carry the separator.
    function _parse(text) {
        const rows = text.trim().split("\n").map(line => {
            const f = line.split(":");
            return {
                device: f[0],
                type: f[1],
                state: f[2],
                name: f.slice(3).join(":").replace(/\\:/g, ":")
            };
        });

        const up = rows.filter(r => r.state?.startsWith("connected"));
        const dev = up.find(r => r.type === "ethernet") ?? up.find(r => r.type === "wifi");

        root.type = dev?.type ?? "";
        root.name = dev?.name ?? "";
        root.device = dev?.device ?? "";
    }

    // Two lines, rx then tx, in the order cat was handed them.
    function _counted(text) {
        const lines = text.trim().split("\n");
        if (lines.length < 2) return;

        const rx = parseInt(lines[0]);
        const tx = parseInt(lines[1]);
        // An interface that went away between the binding and the read leaves
        // cat with nothing to print and parseInt with NaN, which would poison
        // every number downstream of it.
        if (!isFinite(rx) || !isFinite(tx)) return;

        const now = Date.now();
        const prev = root._prev;
        root._prev = { rx: rx, tx: tx, at: now };

        root.rxTotal = rx;
        root.txTotal = tx;

        // Nothing to subtract from: this sample is the predecessor of the next
        // one and no rate is published for it.
        if (!prev) return;

        const secs = (now - prev.at) / 1000;
        // A predecessor older than a few poll intervals is no predecessor at
        // all. The popup was shut in between, so the difference would be an
        // average over however long it stayed shut -- a five-minute mean drawn
        // as one one-second sample, which flattens the graph and misreports the
        // moment. It is discarded and the next pair measures the link properly.
        // The same test catches a clock that stepped backwards under NTP.
        if (secs <= 0 || secs > 3) return;

        // The counters restart at zero when the interface is taken down and
        // brought back up. The negative difference that follows is not a
        // negative speed and the positive one after a switch of interface is
        // not a spike; both are simply a new counter that has not been sampled
        // twice yet.
        if (rx < prev.rx || tx < prev.tx) return;

        root.rxRate = (rx - prev.rx) / secs;
        root.txRate = (tx - prev.tx) / secs;
        root.history = root.history
            .concat([{ rx: root.rxRate, tx: root.txRate }])
            .slice(-root.historyMax);
    }

    // The sample the next one is measured against: { rx, tx, at }, or null when
    // there is nothing to measure against yet.
    property var _prev: null

    // A different interface is a different set of counters and a different line
    // on the graph, so none of the old numbers survive the change. Priming
    // straight away costs one read and means the totals in the popup are true
    // on the frame it opens, rather than being zero until the first tick.
    onDeviceChanged: {
        root._prev = null;
        root.rxRate = -1;
        root.txRate = -1;
        root.rxTotal = 0;
        root.txTotal = 0;
        root.history = [];
        root.sample();
    }

    Process {
        id: query
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    Process {
        id: counters
        command: ["cat",
            "/sys/class/net/" + root.device + "/statistics/rx_bytes",
            "/sys/class/net/" + root.device + "/statistics/tx_bytes"]
        stdout: StdioCollector {
            onStreamFinished: root._counted(this.text)
        }
    }

    // NetworkManager pushes a line on every state change; re-query on each.
    Process {
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: query.running = true
        }
    }
}
