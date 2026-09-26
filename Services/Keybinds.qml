pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Backs KeybindOverview.qml (SUPER+K): every bind Hyprland is running right
// now, searchable by what it does or by the keys it sits on.
//
// The rows come from `scripts/keybinds.sh --tsv`, which decodes
// `hyprctl binds` -- this used to be shared with a rofi cheat sheet on
// SUPER+H, since replaced by this overview, but the decode still lives in
// the script rather than here so modmask bits and key names are turned into
// "SUPER + SHIFT + S" in exactly one place. Read
// again on every open rather than once at startup: a saved hyprland.lua
// reloads the binds under a running shell, and a cheat sheet that still shows
// the old ones is worse than none.
Singleton {
    id: root

    property bool open: false
    property string query: ""

    // [{ keys: ["SUPER", "K"], action: "Keybind overview", ref: "12", haystack }]
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

    // --- keybind-overrides.lua: user rebinds, round-tripped through this file
    //
    // Written ONLY here, never hyprland.lua -- KeybindManager.qml (the edit
    // mode of KeybindOverview.qml) is the only caller of saveOverride/
    // resetOverrides. The guarded loader at the very end of hyprland.lua
    // runs this file (see the comment there for the mechanism); a missing
    // or empty file is defined there as a no-op, which is exactly what
    // resetOverrides leaves behind.
    //
    // Format: a `local overrides = {}` Lua table, one row per line, that
    // this file both writes and re-parses with a regex (never a real Lua
    // parser -- the rows are generated wholesale every time, never
    // hand-edited, so a regex is enough), followed by the loop that applies
    // each row via hl.unbind/hl.bind. Re-parsing on load is what lets a
    // second rebind of an already-remapped row update that row's `to`
    // rather than stacking a second override on top of a `from` that no
    // longer matches anything live.
    readonly property string overridesPath: `${Quickshell.env("HOME")}/.config/hypr/keybind-overrides.lua`
    readonly property string overridesPrevPath: root.overridesPath + ".prev"

    // [{ from, to, ref, description }], parsed back out of the file.
    property var overrideEntries: []
    property bool overridesLoaded: false
    property string _rawOverridesText: ""
    property string _pendingText: ""
    property var _pendingEntries: []
    property bool _restoring: false
    property string _restoreError: ""

    // Emitted once a save/reset round-trips through `hyprctl reload` +
    // `hyprctl configerrors`. `ok` false means the write was already rolled
    // back to the previous good file (and reloaded again) by the time this
    // fires -- `error` is what configerrors said about the attempt, not
    // about the rollback.
    signal saveFinished(bool ok, string error)

    function _luaEscape(s) {
        return String(s ?? "").replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
    }

    function _decodeOverrides(text) {
        const re = /\{\s*from\s*=\s*"((?:[^"\\]|\\.)*)"\s*,\s*to\s*=\s*"((?:[^"\\]|\\.)*)"\s*,\s*ref\s*=\s*"((?:[^"\\]|\\.)*)"\s*,\s*description\s*=\s*"((?:[^"\\]|\\.)*)"\s*\}/g;
        const unesc = s => s.replace(/\\(.)/g, "$1");
        const out = [];
        let m;
        while ((m = re.exec(text)) !== null)
            out.push({ from: unesc(m[1]), to: unesc(m[2]), ref: unesc(m[3]), description: unesc(m[4]) });
        return out;
    }

    readonly property string _header: "-- Generated by rd-shell's keybind manager (KeybindManager.qml /\n"
        + "-- Services/Keybinds.qml) -- do not hand-edit, it is rewritten wholesale on\n"
        + "-- every rebind and on \"Reset to defaults\". Required from the very end of\n"
        + "-- hyprland.lua (see the loader there); missing or empty is a\n"
        + "-- no-op.\n"
        + "--\n"
        + "-- Each row remaps `from` (the chord hyprland.lua binds at parse time) to\n"
        + "-- `to` (what was picked instead) by re-invoking the original bind's own\n"
        + "-- callback through its Lua registry slot (`ref`) -- the same trick\n"
        + "-- Services/Keybinds.qml's run() uses to fire a bind straight from the\n"
        + "-- overview (`debug.getregistry()[ref]`). That ref is only meaningful for\n"
        + "-- the exact hyprland.lua that produced it: hand-editing that file\n"
        + "-- invalidates every ref here, which \"Reset to defaults\" is the way out of.\n";

    function _encode(entries) {
        const rows = entries.map(o =>
            `    { from = "${root._luaEscape(o.from)}", to = "${root._luaEscape(o.to)}", ref = "${root._luaEscape(o.ref)}", description = "${root._luaEscape(o.description)}" },`
        ).join("\n");
        return root._header + "\nlocal overrides = {\n" + rows + (rows.length ? "\n" : "") + "}\n\n"
            + "for _, o in ipairs(overrides) do\n"
            + "    pcall(hl.unbind, o.from)\n"
            + "    pcall(hl.unbind, o.to)\n"
            + "    hl.bind(o.to, hl.dsp.exec_cmd(string.format(\n"
            + "        [[hyprctl eval \"local f = debug.getregistry()[%s] if type(f) == 'function' then f() end\"]],\n"
            + "        o.ref\n"
            + "    )), { description = (o.description or \"\") .. \" (remapped)\" })\n"
            + "end\n\n"
            + "return overrides\n";
    }

    // Canonical form of one key token, for comparing a captured chord
    // against `root.binds` rather than for anything shown on screen.
    // scripts/keybinds.sh turns hyprctl's raw "left"/"right"/"up"/"down"
    // into arrow glyphs for the keycaps, but KeybindManager.qml's capture
    // path (Qt key codes in, Hyprland's own bind-key spelling out) has no
    // reason to produce those glyphs -- so left uncorrected, a captured
    // "CTRL + ALT + up" would never match displayed "CTRL + ALT + ↑" and a
    // screenshot bind already on that chord would look free. Folding case
    // too means a captured "Return" matches a live "RETURN" (or any other
    // case Hyprland happens to echo back a name in) without either side
    // having to guess the other's spelling.
    function _canonKey(k) {
        switch (k) {
        case "←": return "LEFT";
        case "→": return "RIGHT";
        case "↑": return "UP";
        case "↓": return "DOWN";
        default: return String(k).toUpperCase();
        }
    }

    function _canonCombo(keys) {
        return keys.map(root._canonKey).join(" + ");
    }

    // Live conflict check for the chord being captured -- `root.binds`
    // already reflects whatever is bound *right now*, overrides included,
    // so this catches a clash with another override just as well as with a
    // stock hyprland.lua bind. `excludeRef` leaves out the row being
    // rebound itself, so picking back its own current chord is not "in use".
    function findConflict(comboKeys, excludeRef) {
        const combo = root._canonCombo(comboKeys);
        return root.binds.find(b => b.ref !== excludeRef && root._canonCombo(b.keys) === combo) ?? null;
    }

    // `bind` is a row from `root.binds` (hyprctl's live view); `comboKeys`
    // is the captured chord, e.g. ["SUPER","SHIFT","K"].
    function saveOverride(bind, comboKeys) {
        if (!bind || !/^[0-9]+$/.test(bind.ref ?? "")) return;
        const to = comboKeys.join(" + ");
        const existing = root.overrideEntries.find(o => o.ref === bind.ref);
        const from = existing ? existing.from : bind.keys.join(" + ");
        const description = existing ? existing.description : bind.action.replace(/ \(remapped\)$/, "");
        const rest = root.overrideEntries.filter(o => o.ref !== bind.ref);
        // Picking the row's own original chord back is "remove the
        // override", not "remap to what it already was".
        root._commit(to === from ? rest : rest.concat([{ from, to, ref: bind.ref, description }]));
    }

    function resetOverrides() {
        root._commit([]);
    }

    function _commit(entries) {
        root._pendingEntries = entries;
        root._pendingText = root._encode(entries);
        // Back up what is live right now (possibly "no file yet") before it
        // is overwritten, so a bad write has something to restore to.
        ovPrevFile.setText(root._rawOverridesText);
    }

    function _afterReload(errText) {
        if (errText.length > 0) {
            if (root._restoring) {
                // The restore itself produced errors -- stop rather than
                // loop; the file on disk is whatever the last write left,
                // and the UI gets told.
                root._restoring = false;
                root.lastError = errText;
                root.saveFinished(false, errText);
                return;
            }
            root._restoreError = errText;
            root._restoring = true;
            ovFile.setText(root._rawOverridesText); // last known-good content
            return;
        }
        if (root._restoring) {
            root._restoring = false;
            root.saveFinished(false, root._restoreError);
            return;
        }
        // `hyprctl configerrors` clean is not proof the write took effect --
        // the loader's `pcall(dofile, ...)` swallows
        // a bad overrides file just as quietly as a missing one, so a chord
        // that failed to apply for some other reason would never show up
        // here at all. Re-reading the live binds (the same
        // scripts/keybinds.sh pass every open of this overview uses) and
        // checking each pending `to` actually landed catches that case too.
        root._verifying = true;
        load.running = true;
    }

    property bool _verifying: false

    onBindsChanged: if (root._verifying) root._verifyApplied()

    function _verifyApplied() {
        root._verifying = false;
        const missing = root._pendingEntries.filter(o =>
            !root.binds.some(b => b.keys.join(" + ") === o.to));
        if (missing.length > 0) {
            root._restoreError = `Rebind to "${missing[0].to}" did not take effect`;
            root._restoring = true;
            ovFile.setText(root._rawOverridesText);
            return;
        }
        root.overrideEntries = root._pendingEntries;
        root._rawOverridesText = root._pendingText;
        root.saveFinished(true, "");
    }

    property string lastError: ""

    FileView {
        id: ovFile

        path: root.overridesPath
        preload: true
        // This shell is the only writer -- reacting to its own writes would
        // just re-run the parse it already did in onSaved's caller.
        watchChanges: false
        printErrors: false

        onLoaded: {
            root._rawOverridesText = text();
            root.overrideEntries = root._decodeOverrides(root._rawOverridesText);
            root.overridesLoaded = true;
        }
        // Missing file == no overrides yet, the same thing "Reset to
        // defaults" leaves behind -- not an error.
        onLoadFailed: {
            root._rawOverridesText = "";
            root.overrideEntries = [];
            root.overridesLoaded = true;
        }
        onSaved: reloadCheck.running = true
    }

    FileView {
        id: ovPrevFile

        path: root.overridesPrevPath
        preload: false
        printErrors: false
        onSaved: ovFile.setText(root._pendingText)
    }

    Process {
        id: reloadCheck

        command: ["sh", "-c", "hyprctl reload >/dev/null 2>&1; hyprctl configerrors"]
        stdout: StdioCollector {
            onStreamFinished: root._afterReload(this.text.trim())
        }
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
