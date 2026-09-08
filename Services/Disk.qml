pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Mounted filesystems, re-read from df on a timer.
//
// Grouped by device rather than by mount point: btrfs reports the same pool once
// per mounted subvolume, so / and /home would otherwise be listed as two
// half-terabyte partitions that happen to hold identical numbers.
Singleton {
    id: root

    // One entry per device -- { device, mounts, size, used, avail, percent } --
    // with the root filesystem first and the rest in df's own order.
    property var filesystems: []

    // The disk the system runs off: whichever entry carries "/".
    readonly property var main: root.filesystems.find(f => f.mounts.indexOf("/") !== -1) ?? null

    // -1 until the first df returns, so the pill can stay hidden rather than
    // claim for one frame that the disk is empty.
    readonly property int percent: root.main ? root.main.percent : -1

    readonly property real totalSize: root.filesystems.reduce((sum, f) => sum + f.size, 0)
    readonly property real totalUsed: root.filesystems.reduce((sum, f) => sum + f.used, 0)

    // Opening the popup is exactly the moment somebody wants these current, and
    // df against mounted filesystems costs a few milliseconds.
    function refresh() {
        query.running = true;
    }

    // df escapes whitespace in a mount point as \040, so every column is a
    // single whitespace-free field and the header line is the only one dropped.
    function _parse(text) {
        const byDevice = {};
        const out = [];

        for (const line of text.trim().split("\n").slice(1)) {
            const f = line.trim().split(/\s+/);
            if (f.length < 5) continue;

            const size = parseInt(f[1]);
            // Zero-sized filesystems are pseudo mounts that -x did not name;
            // they would divide the percentage by zero.
            if (!(size > 0)) continue;

            const seen = byDevice[f[0]];
            if (seen) {
                seen.mounts.push(f[4]);
                continue;
            }

            const entry = {
                device: f[0],
                mounts: [f[4]],
                size: size,
                used: parseInt(f[2]),
                avail: parseInt(f[3]),
                // Deliberately used/size and not df's own Use%, which measures
                // against the space left after the reserved blocks: the popup
                // prints used and total, and the bar beside them has to be the
                // fraction those two numbers describe.
                percent: Math.round(parseInt(f[2]) / size * 100)
            };

            byDevice[f[0]] = entry;
            out.push(entry);
        }

        const rootIndex = out.findIndex(f => f.mounts.indexOf("/") !== -1);
        if (rootIndex > 0) out.unshift(out.splice(rootIndex, 1)[0]);

        root.filesystems = out;
    }

    // The pill's own cadence. Ten seconds and not a minute because a btrfs pool
    // under a large write moves gigabytes between two readings, and the popup
    // polls faster still for as long as it is open.
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: query
        command: ["df", "-B1", "--output=source,size,used,avail,target",
            "-x", "tmpfs", "-x", "devtmpfs", "-x", "squashfs", "-x", "efivarfs",
            "-x", "overlay", "-x", "ramfs", "-x", "nsfs", "-x", "fuse.portal"]
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }
}
