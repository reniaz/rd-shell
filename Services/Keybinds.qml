pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Backs KeybindOverview.qml (SUPER+K): every bind Hyprland is running right
// now, searchable by what it does or by the keys it sits on.
//
// The rows come from `scripts/keybinds.sh --tsv`, the same decode of
// `hyprctl binds` the rofi sheet on SUPER+H draws from, so modmask bits and
// key names are turned into "SUPER + SHIFT + S" in exactly one place. Read
// again on every open rather than once at startup: a saved hyprland.lua
// reloads the binds under a running shell, and a cheat sheet that still shows
// the old ones is worse than none.
Singleton {
    id: root

    property bool open: false
    property string query: ""

    // [{ keys: ["SUPER", "SHIFT", "S"], action: "Showcase", ref: "12", haystack }]
    property var binds: []

    function toggle() {
        root.open = !root.open;
    }

    onOpenChanged: if (root.open) load.running = true

    Process {
        id: load

        command: ["sh", Quickshell.shellPath("scripts/keybinds.sh"), "--tsv"]

        stdout: StdioCollector {
            onStreamFinished: root.binds = this.text.split("\n")
                .filter(line => line.includes("\t"))
                .map(line => {
                    const [combo, action, ref] = line.split("\t");
                    return {
                        keys: combo.split(" + "),
                        action,
                        ref: ref ?? "",
                        haystack: `${combo} ${action}`.toLowerCase()
                    };
                })
        }
    }

    // Runs a bind as if its keys had been pressed. Every bind in this Lua
    // config dispatches through `__lua`, whose arg is the callback's slot in
    // the Lua registry, and `hyprctl eval` runs in that same Lua state -- so
    // the callback is called straight out of the registry. `hyprctl dispatch`
    // cannot do it: under a Lua config it wraps its argument in hl.dispatch().
    // The ref comes from `hyprctl binds`, but it is still spliced into Lua
    // source, so anything that is not a plain slot number is refused; the
    // type check covers a slot that stopped holding a function after a config
    // reload between this list being read and Enter being pressed.
    function run(bind) {
        if (!/^[0-9]+$/.test(bind?.ref ?? "")) return;
        Quickshell.execDetached(["hyprctl", "eval",
            `local f = debug.getregistry()[${bind.ref}] if type(f) == "function" then f() end`]);
    }

    readonly property var results: root._search(root.query)

    // Every word of the query has to appear somewhere in the row, in any
    // order, so "shift s" and "s shift" both find SUPER + SHIFT + S, and a
    // typed "+" is just noise. Rows whose action starts with the query come
    // first; everything else keeps hyprland.lua's own order, which already
    // groups related binds together and is worth more than alphabetical.
    function _search(text) {
        const needle = text.trim().toLowerCase();
        const words = needle.replace(/\+/g, " ").split(/\s+/).filter(w => w.length > 0);
        if (words.length === 0) return root.binds;
        const hits = root.binds.filter(b => words.every(w => b.haystack.includes(w)));
        const lead = hits.filter(b => b.action.toLowerCase().startsWith(needle));
        return lead.concat(hits.filter(b => !lead.includes(b)));
    }
}
