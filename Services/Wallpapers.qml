pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.Config

// What the wallpaper switcher overlay browses and acts on. The tree itself
// lives on disk; this only ever holds one directory's listing at a time and
// the path that got it there, so entering a folder never has to reconcile a
// deep cache against files the user added since the panel was last open --
// wallpaper-scan.sh re-reads and re-thumbnails the one directory shown, on
// every navigation, and that is cheap enough (see its own comments) that
// there is nothing to gain from remembering more than that.
//
// Named `wp` rather than the usual `root`: the contract this singleton is
// coded against calls its wallpaper-tree property `root`, and QML will not
// let an id and a property share a name.
Singleton {
    id: wp

    readonly property string root: `${Quickshell.env("HOME")}/Pictures/wall`
    property string dir: wp.root
    readonly property bool atRoot: wp.dir === wp.root

    // The part of `dir` past `root`, with the leading slash trimmed -- "" at
    // root, "LainOS-wallpapers/Wallhaven" three levels down.
    readonly property string label: wp.atRoot ? "" : wp.dir.slice(wp.root.length + 1)

    readonly property var entries: wp._entries
    readonly property bool scanning: query.running

    // Mirrors ~/.cache/rd-shell/wallpaper, the file wallpaper-apply.sh writes
    // as its last act and only on success -- but apply() below sets this the
    // moment the user picks something, before the detached script has even
    // started. The click is the one piece of certain knowledge in the whole
    // chain; matugen, the file write, and the inotify round trip back through
    // the FileView below are seconds of latency with several ways to fail
    // silently, and both the switcher and Wallpaper.qml treat `current` as
    // "what should be on screen right now" -- so it should say what the user
    // picked immediately, not lag behind a background process that might
    // never finish. The known cost is a card whose image has been deleted
    // since the folder was scanned: `current` would name a file that is
    // never actually applied, and nothing here corrects that if the script
    // exits before writing the state file. That is a worse-than-nothing
    // wallpaper name sitting in a property versus a wallpaper that visibly
    // never changes when the user picks one -- the latter is the bug being
    // fixed. The FileView below still overwrites this with the real state
    // the moment a write does land, so any optimistic guess that turns out
    // right (the overwhelmingly common case) is confirmed, and one that
    // disagrees is corrected rather than left standing forever.
    readonly property string current: wp._current
    property string _current: ""

    property bool panelOpen: false

    property var _entries: []

    // Set only by the open below, for the one failure it can cause that no
    // other scan can. See the catch in `_accept`.
    property bool _openScan: false

    function togglePanel() {
        wp.panelOpen = !wp.panelOpen;

        // Opening starts in the folder holding the wallpaper that is on
        // screen, so the strip comes up centred on the picture you are
        // actually looking at however deep in the tree it lives. This is not
        // the panel remembering where you browsed last -- that would be state
        // you never asked it to keep -- it is the panel opening on the only
        // thing it can know you care about, and it is what already happened
        // for a wallpaper sitting directly in ~/Pictures/wall: the switcher
        // centres on whichever card matches `current`, and the root listing
        // only ever contained that card when the wallpaper was not in a
        // subfolder.
        if (wp.panelOpen) {
            wp.dir = wp._startDir();
            wp._openScan = wp.dir !== wp.root;
            wp._scan(wp.dir);
        }
    }

    // The directory a fresh open should land in.
    function _startDir() {
        // Bounded with the separator, the way open() and back() do it: a bare
        // prefix test would accept a sibling directory whose name merely
        // starts with the root's. It also rejects "" -- `current` before the
        // state file has been read -- and any wallpaper applied from outside
        // the tree, both of which start at the top instead.
        if (!wp.current.startsWith(wp.root + "/")) return wp.root;

        // Given that test, this is `root` itself or a directory inside it, so
        // the bounds are already established and are not re-checked here.
        return wp.current.slice(0, wp.current.lastIndexOf("/"));
    }

    // Refuses anything outside `root` itself, independent of the scan
    // script's own refusal -- the invariant holds even if a bogus path
    // reaches here some way other than an entry the script produced.
    function open(path) {
        if (path !== wp.root && !path.startsWith(wp.root + "/")) return;
        wp.dir = path;
        wp._scan(path);
    }

    function back() {
        if (wp.atRoot) return;

        // Bounded with the separator, the same way open() does it: a bare
        // prefix test would accept a sibling directory whose name merely
        // starts with the root's, and the invariant open() documents is
        // meant to hold however `dir` came to be what it is.
        const parent = wp.dir.slice(0, wp.dir.lastIndexOf("/"));
        wp.dir = parent.startsWith(wp.root + "/") || parent === wp.root ? parent : wp.root;
        wp._scan(wp.dir);
    }

    function apply(path) {
        // Set before the detached process even starts -- see the comment on
        // `current` above for why this is optimistic rather than waiting on
        // the state file.
        wp._current = path;
        Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/wallpaper-apply.sh"), path]);
        wp.panelOpen = false;
    }

    function refresh() {
        wp._scan(wp.dir);
    }

    function _scan(path) {
        // Cleared up front rather than left showing the previous folder while
        // the new one loads: PathView would otherwise animate through cards
        // that are about to be replaced, and the invariant is that `entries`
        // reads empty during a scan, not stale.
        wp._entries = [];

        // `command` only takes effect at the next launch, so a scan already
        // in flight -- the user flicking through folders faster than
        // wallpaper-scan.sh returns -- is stopped first rather than having
        // its argument silently swapped out from under it.
        query.running = false;
        query.exec(["sh", Quickshell.shellPath("scripts/wallpaper-scan.sh"), path]);
    }

    function _accept(text) {
        // Deliberately not deduplicated against the last reply. `_scan` empties
        // `_entries` before every run, so an identical answer is not a no-op to
        // skip -- it is the only thing that will ever put the cards back. A
        // content check here left the strip permanently empty from the second
        // time the panel was opened on the same folder onwards.
        try {
            const next = JSON.parse(text);
            if (!next || !Array.isArray(next.entries)) return;

            // The script echoes back the directory it actually scanned, so a
            // reply that lands after the user has already navigated on --
            // Wallhaven's 112 thumbnails take real seconds the first time --
            // is matched against where we are now rather than trusted blind.
            if (next.dir !== wp.dir) return;

            wp._openScan = false;
            wp._entries = next.entries;
        } catch (e) {
            // Invalid JSON reads as a failed scan: `_entries` was already
            // cleared to [] when the scan launched, and stays that way.
            //
            // One case cannot be left like that. Opening now starts in the
            // folder that held the wallpaper when it was applied, and that
            // folder can have been renamed or deleted since -- the scan
            // refuses a directory that is not there, so the panel would come
            // up on an empty strip with no back card on it to leave by, and
            // reopening would land in the same dead folder again. Retreating
            // to the root turns that into the behaviour this open replaced.
            //
            // Guarded by `_openScan` rather than applied to every failed
            // scan, because a scan killed mid-flight by the next one lands
            // here too with an empty read: navigating faster than the script
            // returns would otherwise throw the user back to the root. Only
            // the open sets the flag, and nothing is ever in flight when the
            // panel is shut, so the two cannot be confused.
            if (wp._openScan) {
                wp._openScan = false;
                wp.dir = wp.root;
                wp._scan(wp.root);
            }
        }
    }

    Process {
        id: query

        stdout: StdioCollector {
            onStreamFinished: wp._accept(this.text)
        }
    }

    // --- accent preview ------------------------------------------------------
    //
    // The switcher asks what a wallpaper *would* recolour the shell to, before
    // it is applied. scripts/wallpaper-preview.sh answers with the same roles
    // JSON the bar reads, computed through the same scheme and mode the apply
    // would use, and writes nothing the live shell reads.
    //
    // Results are kept for the session because the strip is browsed back and
    // forth: the script caches on disk too, but not re-spawning a process for
    // a card the user already scrolled past is what keeps a fast flick through
    // the fan from queueing twenty of them.

    // Set by the switcher to the centred card's path, or "" for a folder card
    // and while the panel is closed.
    property string previewPath: ""

    // The roles for `previewPath`, or null while they are being computed or if
    // matugen could not answer. Consumers must handle null: the first look at
    // any wallpaper has no answer yet by definition.
    readonly property var previewRoles: wp._previewRoles

    property var _previewRoles: null
    property var _previewCache: ({})
    property string _previewPending: ""

    onPreviewPathChanged: {
        const path = wp.previewPath;
        if (path === "") {
            wp._previewRoles = null;
            previewDebounce.stop();
            return;
        }
        // A cached answer is shown immediately and without a timer: the delay
        // below exists to avoid spawning processes for cards that are merely
        // being scrolled through, and a cache hit spawns nothing.
        const hit = wp._previewCache[path];
        if (hit !== undefined) {
            wp._previewRoles = hit;
            previewDebounce.stop();
            return;
        }
        wp._previewRoles = null;
        previewDebounce.restart();
    }

    Timer {
        id: previewDebounce

        // Long enough that flicking through the fan does not start a process
        // per card, short enough that stopping on one feels like it answered
        // rather than like it thought about it.
        interval: 180

        onTriggered: {
            if (wp.previewPath === "" || preview.running)
                return;
            wp._previewPending = wp.previewPath;
            preview.command = [
                `${Quickshell.env("HOME")}/.config/quickshell/rd-shell/scripts/wallpaper-preview.sh`,
                wp.previewPath
            ];
            preview.running = true;
        }
    }

    Process {
        id: preview

        stdout: StdioCollector {
            onStreamFinished: {
                const path = wp._previewPending;
                if (path === "")
                    return;
                let roles = null;
                try {
                    roles = JSON.parse(this.text);
                } catch (e) {
                    // A wallpaper matugen cannot read is not an error worth
                    // showing: the swatches simply do not appear for it.
                    roles = null;
                }
                wp._previewCache[path] = roles;
                if (wp.previewPath === path)
                    wp._previewRoles = roles;
                wp._previewPending = "";
            }
        }

        // The debounce only starts one process at a time, so a card centred
        // while another preview was still running never got its own run.
        onRunningChanged: if (!preview.running && wp.previewPath !== ""
            && wp._previewCache[wp.previewPath] === undefined)
            previewDebounce.restart();
    }

    // Dropped whenever the scheme itself changes, not only the wallpaper --
    // toggling Settings.wallpaperColours is exactly that, and every cached
    // answer above was computed under whichever scheme was live at the time.
    // Left in place they would go on showing the wrong swatches for any card
    // already scrolled past. wallpaper-preview.sh's own on-disk cache is
    // keyed to survive this by itself; this in-memory one is not, and is only
    // ever cleared by hand.
    Connections {
        target: Settings

        function onWallpaperColoursChanged() {
            wp._previewCache = {};
            wp._previewRoles = null;
            if (wp.previewPath !== "")
                previewDebounce.restart();
        }
    }

    FileView {
        path: `${Quickshell.env("HOME")}/.cache/rd-shell/wallpaper`
        watchChanges: true
        onFileChanged: reload()
        // Deliberately unconditional: this is the correction half of the
        // optimistic update in apply() above, so a real write always wins
        // over whatever guess `current` is currently holding.
        onLoaded: wp._current = text().trim()
        // Left alone on failure: if the file can't be read, whatever
        // `current` already holds -- the optimistic value apply() just set,
        // or the last confirmed one -- is a better guess than clearing it.
    }

    // ── session-aware wallpaper (§7.5) ────────────────────────────────────
    // Entirely inert unless Caelus.autoWallpaper is on: the Timer's
    // `running` below is bound to it directly rather than checked inside
    // onTriggered, so turning the setting off mid-session stops the clock
    // being read at all, not just stops it from acting on what it reads.
    property string _autoBand: ""

    // Order-independent by design: bands are found by comparing every entry
    // rather than assuming Caelus.wallpaperBands is sorted, so a reordered
    // or hand-edited list still resolves correctly.
    function _bandForHour(hour) {
        const bands = Caelus.wallpaperBands;
        if (!bands || bands.length === 0) return null;

        // The band with the single latest startHour of the day -- the
        // fallback for the hours before the first boundary, which still
        // belong to the previous night's band rather than to no band at all.
        let latest = bands[0];
        for (let i = 1; i < bands.length; i++) {
            if (bands[i].startHour > latest.startHour) latest = bands[i];
        }

        // Among the bands that have already started today, the one whose
        // startHour is closest to, without going past, the current hour.
        let active = null;
        for (let i = 0; i < bands.length; i++) {
            const b = bands[i];
            if (b.startHour <= hour && (active === null || b.startHour > active.startHour))
                active = b;
        }
        return active !== null ? active : latest;
    }

    // The same call apply() makes, minus the panel-closing side effect: the
    // switcher is never open when a boundary crosses in the background, and
    // forcing panelOpen shut here would fight a user who happens to have it
    // open for an unrelated reason at the exact moment the clock ticks over.
    function _applyBand(path) {
        wp._current = path;
        Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/wallpaper-apply.sh"), path]);
    }

    function _checkBand() {
        const band = wp._bandForHour(new Date().getHours());
        if (band === null) return;

        if (wp._autoBand === "") {
            // First check of the session (including the first check right
            // after autoWallpaper is switched on): adopt whatever band the
            // clock already says we are in without touching the wallpaper,
            // so neither starting the shell nor turning the setting on ever
            // changes what is on screen by itself -- only an actual
            // boundary crossing during the session does that, below. This is
            // also what keeps a manual pick from earlier in the same band
            // standing rather than being immediately overwritten.
            wp._autoBand = band.name;
            return;
        }

        // Still the same band as last time: nothing to do, and nothing to
        // fight -- a wallpaper the user picked by hand after the last
        // boundary stays exactly as they left it until the next one.
        if (band.name === wp._autoBand) return;

        wp._autoBand = band.name;
        wp._applyBand(band.path);
    }

    // A five-minute poll rather than a Date-boundary alarm: the boundaries
    // are whole hours, so a check this often is never more than a few
    // minutes late crossing one, and four bands a day means the timer can
    // only ever trigger a real wallpaper change a handful of times --
    // matugen only reruns on an actual band change, never on a poll that
    // finds the same band still active.
    Timer {
        running: Caelus.autoWallpaper
        repeat: true
        triggeredOnStart: true
        interval: 5 * 60 * 1000
        onTriggered: wp._checkBand()
    }
}
