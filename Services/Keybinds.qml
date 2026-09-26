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

    // [{ keys: ["SUPER", "K"], action: "Keybind overview", ref: "12",
    //   raw: "SUPER + K", haystack }]. `keys`/the joined display combo are
    // for on-screen keycaps only (arrow glyphs, "Audio Raise Volume", ...);
    // `raw` is the same chord in Hyprland's own spelling and is what every
    // comparison against a captured chord or an override's from/to uses.
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
                    const [combo, action, ref, raw] = line.split("\t");
                    return {
                        keys: combo.split(" + "),
                        action,
                        ref: ref ?? "",
                        raw: raw ?? combo,
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

    // Emitted exactly once per _commit(), once a save/reset round-trips
    // through `hyprctl reload` + `hyprctl configerrors` (see `_finish`
    // below, the only place this is emitted from). `ok` false means the
    // write was already rolled back to the previous good file (and reloaded
    // again) by the time this fires -- `error` is what configerrors said
    // about the attempt, not about the rollback. `token` is whatever the
    // `_commit()` that led here returned -- a listener that kicked off its
    // own save/reset and kept that return value can compare it here to
    // ignore a result meant for a different one (an old capture's save
    // finishing late after the user has since opened another, say).
    signal saveFinished(bool ok, string error, int token)

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
        + "-- `to` (what was picked instead). hyprland.lua wraps hl.bind before its own\n"
        + "-- binds run and records each one in the global rd_bind_registry, keyed by\n"
        + "-- its canonical chord -- looking `from` up there hands back the ORIGINAL\n"
        + "-- dispatcher and options to re-bind onto `to`, which keeps working no\n"
        + "-- matter how the registry slots in that file shift around on an edit.\n"
        + "-- `ref` (a Lua registry slot) is kept only so a hyprland.lua predating that\n"
        + "-- wrapper -- rd_bind_registry missing entirely, not just missing this row --\n"
        + "-- can still fall back to invoking the bind straight out of the registry,\n"
        + "-- the way this file used to work everywhere. Hand-editing hyprland.lua can\n"
        + "-- still remove the `from` this row depends on; \"Reset to defaults\" is the\n"
        + "-- way out of that.\n";

    function _encode(entries) {
        const rows = entries.map(o =>
            `    { from = "${root._luaEscape(o.from)}", to = "${root._luaEscape(o.to)}", ref = "${root._luaEscape(o.ref)}", description = "${root._luaEscape(o.description)}" },`
        ).join("\n");
        return root._header + "\nlocal overrides = {\n" + rows + (rows.length ? "\n" : "") + "}\n\n"
            + "local function rd_canon(keys)\n"
            + "    local parts = {}\n"
            + "    for token in tostring(keys):gmatch(\"[^+]+\") do\n"
            + "        local t = token:match(\"^%s*(.-)%s*$\")\n"
            + "        if t ~= \"\" then parts[#parts + 1] = t end\n"
            + "    end\n"
            + "    if #parts == 0 then return \"\" end\n"
            + "    local key = table.remove(parts)\n"
            + "    local order = { SUPER = 1, CTRL = 2, ALT = 3, SHIFT = 4 }\n"
            + "    for i, t in ipairs(parts) do parts[i] = t:upper() end\n"
            + "    table.sort(parts, function(a, b) return (order[a] or 99) < (order[b] or 99) end)\n"
            + "    parts[#parts + 1] = key\n"
            + "    return table.concat(parts, \",\")\n"
            + "end\n\n"
            + "for _, o in ipairs(overrides) do\n"
            + "    if rd_bind_registry then\n"
            + "        -- Robust path: `from` still bound in this hyprland.lua -- unbind it\n"
            + "        -- and whatever sits on `to`, then re-bind the ORIGINAL dispatcher and\n"
            + "        -- options onto `to`. `from` missing from the table just means this\n"
            + "        -- exact bind no longer exists in the current hyprland.lua -- skip\n"
            + "        -- the row quietly rather than guess.\n"
            + "        local entry = rd_bind_registry[rd_canon(o.from)]\n"
            + "        if entry then\n"
            + "            pcall(hl.unbind, o.from)\n"
            + "            pcall(hl.unbind, o.to)\n"
            + "            local opts = {}\n"
            + "            if entry.opts then for k, v in pairs(entry.opts) do opts[k] = v end end\n"
            + "            opts.description = (o.description or \"\") .. \" (remapped)\"\n"
            + "            pcall(hl.bind, o.to, entry.dispatcher, opts)\n"
            + "        end\n"
            + "    else\n"
            + "        -- No registry at all -- an older or hand-edited hyprland.lua without\n"
            + "        -- the rd_bind_registry wrapper. Fall back to re-invoking the\n"
            + "        -- original bind's own callback through its Lua registry slot, only\n"
            + "        -- meaningful for the exact hyprland.lua that produced `ref`.\n"
            + "        pcall(hl.unbind, o.from)\n"
            + "        pcall(hl.unbind, o.to)\n"
            + "        hl.bind(o.to, hl.dsp.exec_cmd(string.format(\n"
            + "            [[hyprctl eval \"local f = debug.getregistry()[%s] if type(f) == 'function' then f() end\"]],\n"
            + "            o.ref\n"
            + "        )), { description = (o.description or \"\") .. \" (remapped)\" })\n"
            + "    end\n"
            + "end\n\n"
            + "return overrides\n";
    }

    readonly property var _modOrder: ({ SUPER: 1, CTRL: 2, ALT: 3, SHIFT: 4 })

    // Canonical form of a chord in Hyprland's OWN spelling ("SUPER + SHIFT +
    // up", "XF86AudioRaiseVolume", a captured ["SUPER","SHIFT","F12"], a
    // `from`/`to` string out of keybind-overrides.lua, a live bind's `raw`)
    // -- modifiers upper-cased and sorted into a fixed order, the key token
    // left exactly as given. hl.bind's own key names already match
    // hyprctl's `key` field byte for byte (arrows stay lowercase, XF86 names
    // keep their mixed case), so folding case on the key would only make two
    // spellings of the same key stop matching each other -- the mirror of
    // hyprland.lua's own rd_canon_chord, which every from/to here has to
    // agree with since that is what unbinds and re-binds them.
    function _canonChord(chord) {
        const parts = (Array.isArray(chord) ? chord : String(chord ?? "").split("+"))
            .map(s => String(s).trim()).filter(s => s.length > 0);
        if (parts.length === 0) return "";
        const key = parts.pop();
        const mods = parts.map(p => p.toUpperCase())
            .sort((a, b) => (root._modOrder[a] ?? 99) - (root._modOrder[b] ?? 99));
        return mods.concat([key]).join(",");
    }

    // Live conflict check for the chord being captured -- `root.binds`
    // already reflects whatever is bound *right now*, overrides included,
    // so this catches a clash with another override just as well as with a
    // stock hyprland.lua bind. `excludeRaw` leaves out the row being
    // rebound itself (its current raw chord), so picking back its own
    // current chord is not "in use".
    function findConflict(comboKeys, excludeRaw) {
        const combo = root._canonChord(comboKeys);
        const exclude = root._canonChord(excludeRaw ?? "");
        return root.binds.find(b => root._canonChord(b.raw) !== exclude && root._canonChord(b.raw) === combo) ?? null;
    }

    // `bind` is a row from `root.binds` (hyprctl's live view, Hyprland
    // spelling in `raw`); `comboKeys` is the captured chord, e.g.
    // ["SUPER","SHIFT","K"], also Hyprland spelling (see
    // KeybindManager.qml's `_keyName`). Rows are matched to an existing
    // override by the chord `bind` is on right now (its `to` if it is
    // already remapped), not by `ref` -- a ref is only ever meaningful for
    // one exact hyprland.lua, so keying this lookup on it would make a
    // second rebind of an already-remapped row stack a new override on top
    // instead of updating it the moment hyprland.lua changes underneath.
    // Returns the token this attempt's eventual `saveFinished` will carry
    // (or undefined if `bind` can't be saved at all and no commit starts).
    function saveOverride(bind, comboKeys) {
        if (!bind || !/^[0-9]+$/.test(bind.ref ?? "")) return;
        const to = comboKeys.join(" + ");
        const bindChord = root._canonChord(bind.raw);
        const existing = root.overrideEntries.find(o => root._canonChord(o.to) === bindChord);
        const from = existing ? existing.from : bind.raw;
        const description = existing ? existing.description : bind.action.replace(/ \(remapped\)$/, "");
        const rest = root.overrideEntries.filter(o => o !== existing);
        // Picking the row's own original chord back is "remove the
        // override", not "remap to what it already was".
        return root._commit(root._canonChord(to) === root._canonChord(from) ? rest : rest.concat([{ from, to, ref: bind.ref, description }]));
    }

    // Returns the token this attempt's eventual `saveFinished` will carry.
    function resetOverrides() {
        return root._commit([]);
    }

    // Set for the whole life of one save/reset attempt -- from _commit until
    // _finish below runs -- so commitWatchdog can tell "still working" from
    // "done" without caring which of the several async hops (two file
    // writes, a reload, a re-read of live binds) it is currently in. A save
    // that never reaches _finish for any reason -- a FileView write that
    // silently never signals, `hyprctl` hanging, anything not already
    // anticipated above -- would otherwise leave the dialog on "Saving..."
    // forever with no way out but closing the sheet; the watchdog turns
    // that into a readable error instead.
    property bool _committing: false

    // Bumped once per _commit() and handed back to whoever called it
    // (saveOverride/resetOverrides' return value); every saveFinished
    // carries one, so a listener that kept its own copy can tell a result
    // meant for a save/reset it started from one that belongs to whatever
    // the singleton is doing now.
    property int _commitToken: 0
    // The token of the save/reset actually in flight -- what `_finish`
    // stamps, so a refused overlapping attempt (see _commit) bumping
    // _commitToken cannot relabel the real result.
    property int _activeToken: 0

    Timer {
        id: commitWatchdog
        interval: 6000
        onTriggered: {
            if (!root._committing) return;
            root._finish(false, "Save timed out -- the write or reload never finished");
        }
    }

    // The one place saveFinished is emitted from, so every terminal exit --
    // success, a rollback that landed, a rollback that itself failed, or the
    // watchdog giving up -- clears exactly the same in-flight state and
    // fires the signal exactly once. A path that cleared `_committing` (or
    // stopped the watchdog) on its own instead used to leave the other
    // half armed, so the watchdog could still fire minutes later and hand a
    // stray "timed out" to whatever the dialog is doing by then.
    function _finish(ok, error) {
        root._committing = false;
        root._verifying = false;
        root._restoring = false;
        commitWatchdog.stop();
        if (!ok) root.lastError = error;
        root.saveFinished(ok, error, root._activeToken);
    }

    // Returns the token this attempt's `saveFinished` will carry.
    function _commit(entries) {
        // One write/reload/verify at a time: a dialog cancelled mid-save
        // leaves that save running, and a second one started on top would
        // swap _pendingText/_pendingEntries out from under it. The refusal
        // is still a saveFinished, deferred so the caller has stored the
        // token first.
        if (root._committing) {
            const busy = ++root._commitToken;
            Qt.callLater(() => root.saveFinished(false, "Another save is still finishing -- try again in a moment", busy));
            return busy;
        }
        root._committing = true;
        root._activeToken = ++root._commitToken;
        commitWatchdog.restart();
        root._pendingEntries = entries;
        root._pendingText = root._encode(entries);
        // Best-effort on-disk copy of what's about to be replaced -- purely
        // a manual-recovery copy for the user (never read back by this
        // shell), so it fires and is forgotten: nothing below waits on its
        // `saved`, which, same FileView.setText() no-op semantics as
        // _writeOverrides relies on below, may never come -- two resets in a
        // row, say, ask it to write the same text it already wrote last
        // time.
        ovPrevFile.setText(root._rawOverridesText);
        root._writeOverrides(root._pendingText);
        return root._activeToken;
    }

    // What `ovFile` currently believes is on disk -- kept in lockstep with
    // its own internal belief by updating it at exactly the moment (and
    // only the moment) something here calls `ovFile.setText`, since that is
    // when the FileView's belief itself changes, synchronously, whether or
    // not the write it then kicks off has actually finished. Seeded from
    // the real load (see `ovFile.onLoaded`/`onLoadFailed` below).
    property string _ovBelief: ""

    // FileView.setText() only actually writes -- and only then fires
    // `saved`, which is what the rest of the chain waits on -- when the
    // given text differs from what it already believes is on disk.
    // Checking against `_ovBelief` first says whether a write is even
    // coming: resetting twice in a row, rebinding a chord back onto itself,
    // re-saving an identical remap, or restoring content that was never
    // actually written (a verify failure right after a same-text commit)
    // all land here with nothing that actually needs to change on disk, and
    // waiting on an onSaved that will then never fire is how a save used to
    // hang. Skip straight to the reload/verify step instead -- it still
    // confirms the live binds already match what was asked for.
    function _writeOverrides(text) {
        if (text === root._ovBelief) {
            reloadCheck.running = true;
            return;
        }
        root._ovBelief = text;
        ovFile.setText(text);
    }

    function _afterReload(errText) {
        if (errText.length > 0) {
            if (root._restoring) {
                // The restore itself produced errors -- stop rather than
                // loop; the file on disk is whatever the last write left,
                // and the UI gets told.
                root._finish(false, errText);
                return;
            }
            root._restoreError = errText;
            root._restoring = true;
            root._writeOverrides(root._rawOverridesText); // last known-good content
            return;
        }
        if (root._restoring) {
            root._finish(false, root._restoreError);
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
            !root.binds.some(b => root._canonChord(b.raw) === root._canonChord(o.to)));
        if (missing.length > 0) {
            root._restoreError = `Rebind to "${missing[0].to}" did not take effect`;
            root._restoring = true;
            root._writeOverrides(root._rawOverridesText);
            return;
        }
        root.overrideEntries = root._pendingEntries;
        root._rawOverridesText = root._pendingText;
        root._finish(true, "");
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
            root._ovBelief = root._rawOverridesText;
            root.overrideEntries = root._decodeOverrides(root._rawOverridesText);
            root.overridesLoaded = true;
        }
        // Missing file == no overrides yet, the same thing "Reset to
        // defaults" leaves behind -- not an error.
        onLoadFailed: {
            root._rawOverridesText = "";
            root._ovBelief = "";
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
        // Fire-and-forget: a manual-recovery copy on disk, not part of the
        // save chain (see `_commit`), so nothing here needs to react to it.
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
