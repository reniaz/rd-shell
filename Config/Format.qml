pragma Singleton
import Quickshell
import QtQuick

// The bar's shared number-to-text rules. Sizes and durations are printed by the
// disk popup, the system popup and anything added later; when two widgets
// disagree about whether 9.4G rounds to 9G, the reader assumes one of them is
// wrong rather than that they were written months apart.
Singleton {
    id: root

    // Powers of 1024, matching what df -h prints. One decimal below ten so 9.4G
    // does not collapse to 9G, none above it: a popup that stacks two of these
    // per row needs no fraction on 512G.
    function human(bytes) {
        const units = ["B", "K", "M", "G", "T", "P"];
        let value = bytes;
        let unit = 0;

        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024;
            unit++;
        }

        return (unit === 0 || value >= 10 ? value.toFixed(0) : value.toFixed(1)) + units[unit];
    }

    // Two units at most, largest first: an uptime is read for its order of
    // magnitude, and "1d 11h 20m 3s" says nothing "1d 11h" does not.
    function duration(seconds) {
        const d = Math.floor(seconds / 86400);
        const h = Math.floor(seconds % 86400 / 3600);
        const m = Math.floor(seconds % 3600 / 60);

        if (d > 0) return d + "d " + h + "h";
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    // Whole degrees. Tenths from a thermal sensor are noise -- the same silicon
    // reads two degrees apart depending on which core answered.
    function temp(celsius) {
        return celsius >= 0 ? Math.round(celsius) + "°" : "--";
    }
}
