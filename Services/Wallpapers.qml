pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

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
    // chain; pywal, the file write, and the inotify round trip back through
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

    function togglePanel() {
        wp.panelOpen = !wp.panelOpen;

        // Opening always starts at the top of the tree. Reopening into the
        // folder you were last in reads as the panel having remembered
        // something you did not ask it to, and there is no way back up past
        // the root to undo it -- so every press of the keybind starts the
        // walk from ~/Pictures/wall.
        if (wp.panelOpen) {
            wp.dir = wp.root;
            wp._scan(wp.root);
        }
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

            wp._entries = next.entries;
        } catch (e) {
            // Invalid JSON reads as a failed scan: `_entries` was already
            // cleared to [] when the scan launched, and stays that way.
        }
    }

    Process {
        id: query

        stdout: StdioCollector {
            onStreamFinished: wp._accept(this.text)
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
}
