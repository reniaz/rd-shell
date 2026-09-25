pragma Singleton
import Quickshell
import QtQuick

// The desktop-entry index behind Launcher.qml -- the Quickshell replacement
// for `rofi -show drun` (SUPER+SPACE in hyprland.lua). A Singleton so the
// index is built once and shared by however many times the launcher window
// itself is created and torn down.
Singleton {
    id: root

    // What the launcher's search field is bound to. Read from here rather
    // than owned by the window so a future second consumer (a command
    // palette, a settings search) could drive the same index without
    // standing up a text field of its own.
    property string query: ""

    // Whether the launcher window should be up. Owned here and not by
    // Launcher.qml itself, the same way Power.menuOpen and
    // Wallpapers.panelOpen live in their services rather than their
    // windows: Bar.qml runs one instance per monitor, so the flag that says
    // whether the one, keyboard-exclusive launcher is open needs a home
    // every one of them shares.
    property bool open: false

    function toggle() {
        root.open = !root.open;
    }

    // One entry per visible app, with its searchable text lowercased and
    // split into words up front. This only changes when apps are installed
    // or removed; `query` changes on every keystroke -- so the cost that
    // scales with typing speed must not also scale with the size of the
    // app list. DesktopEntries.applications already excludes Hidden and
    // NoDisplay entries, but the noDisplay check is kept here too: it is
    // one cheap comparison against a real requirement, not a guess about
    // what the model does internally, and it costs nothing if the model
    // was already filtering it.
    readonly property var _index: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .map(e => {
            const name = (e.name ?? "").toLowerCase();
            return {
                entry: e,
                displayName: e.name ?? "",
                name,
                // Split on anything that is not a letter or digit, so a
                // word-boundary match finds "the second word" of a name
                // and not just its start -- "image" finds "GNU Image
                // Manipulation Program" as a word hit rather than only a
                // substring one.
                words: name.split(/[^a-z0-9]+/).filter(w => w.length > 0),
                // Every field a launcher search reasonably covers: the name
                // again (so a haystack hit still counts once a name-only
                // check has already failed), the short description, the
                // parsed command, and whatever keywords the entry declares
                // for exactly this purpose.
                haystack: [e.name, e.genericName, e.execString, ...(e.keywords ?? [])]
                    .filter(s => s)
                    .join(" ")
                    .toLowerCase()
            };
        })

    readonly property var results: root._search(root.query)

    // Four tiers: an exact prefix on the name is the strongest possible
    // signal ("fir" typed for Firefox has to win), a prefix on some later
    // word is the next best ("image" against GIMP's generic name), a
    // substring anywhere is weaker still, and a fuzzy subsequence match is
    // the last resort -- kept because it is sometimes the only way to find
    // something ("ff" for Firefox), but ranked behind everything that could
    // not also be a coincidence.
    function _search(text) {
        const needle = text.trim().toLowerCase();
        if (!needle) {
            return root._index
                .slice()
                .sort((a, b) => a.displayName.localeCompare(b.displayName))
                .map(i => i.entry);
        }

        const hits = [];
        for (const item of root._index) {
            const tier = root._rank(item, needle);
            if (tier !== -1) hits.push({ entry: item.entry, name: item.displayName, tier });
        }

        // Rank first; alphabetical as the tiebreaker, so results tied on
        // rank land in a predictable order instead of whatever order the
        // desktop-entry model happened to hand them in.
        hits.sort((a, b) => a.tier - b.tier || a.name.localeCompare(b.name));
        return hits.map(h => h.entry);
    }

    // -1 means "no match at all"; otherwise lower is a better match.
    function _rank(item, needle) {
        if (item.name.startsWith(needle)) return 0;
        if (item.words.some(w => w.startsWith(needle))) return 1;
        if (item.haystack.includes(needle)) return 2;
        if (root._fuzzy(item.haystack, needle)) return 3;
        return -1;
    }

    // True if every character of `needle` occurs in `haystack` in order,
    // not necessarily next to each other -- "ff" finds "firefox".
    function _fuzzy(haystack, needle) {
        let i = 0;
        for (let c = 0; c < haystack.length && i < needle.length; c++) {
            if (haystack[c] === needle[i]) i++;
        }
        return i === needle.length;
    }

    // An `Icon=` value the desktop file left empty resolves through
    // Quickshell.iconPath("", true) to a result anyway rather than to
    // nothing -- see Services/Workspaces.qml's own note on this, found
    // there when empty workspace slots were drawing a stray icon that
    // belonged to no window. Guarding the empty string here is what keeps
    // that bug out of the launcher too. An `Icon=` that is already an
    // absolute path is the icon, not a name to look up through the theme.
    function iconSource(entry) {
        const icon = entry?.icon ?? "";
        if (!icon) return "";
        if (icon.startsWith("/")) return "file://" + icon;
        return Quickshell.iconPath(icon, true);
    }

    // DesktopEntry.execute() calls Quickshell.execDetached() internally, so
    // the launched app is never a child of the shell process -- closing or
    // restarting the shell cannot take it down with it. Parsing Exec= and
    // detaching by hand here would only reproduce what this already does.
    function launch(entry) {
        if (entry) entry.execute();
    }
}
