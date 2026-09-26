pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.Config

// Idea 40: handwritten-style sticky notes on the desktop. One look for every
// note -- dark and translucent, the same surface/border treatment
// DesktopWidgets.qml's own Spotify card already uses -- with only the
// handwritten font (see below) making a note look different from the rest
// of that desktop-layer chrome.
//
// Persisted notes, one JSON list, one writer -- the same shape
// Services/Reminders.qml already uses for "a list of independent records",
// not Services/Settings.qml's JsonAdapter (that pattern is for a handful of
// named toggles that each want their own alias, which a note is not: every
// note is a fresh id in a growing/shrinking array, and a plain FileView is
// what lets this decide exactly when it writes rather than an adapter
// coalescing changes on its own schedule).
//
// A note: { id, screen, x, y, w, h, text, rotation }
//   screen   -- the Quickshell.screens[].name it was created on. It stays on
//               that monitor even if the set of connected screens changes;
//               StickyNote.qml is what clamps x/y back inside whatever that
//               screen's bounds are *now*, at display time, since this
//               service is never handed live screen geometry to clamp
//               against itself.
//   x, y     -- top-left, relative to that screen's own origin.
//   w, h     -- the note's own size, set only once it has actually been
//               resized (see StickyNote.qml's resize grip). A note that has
//               never been resized -- every note before this feature, and
//               every brand new one -- simply has no w/h field at all;
//               `noteWidth`/`noteHeight` below are what it falls back to,
//               so old and new notes read identically until someone drags a
//               corner.
//   rotation -- degrees, rolled once at creation and kept forever after --
//               the corkboard look wants a fixed tilt per note, not one that
//               reshuffles on every reload.
//
// A note saved by an earlier build of this file also carries a `color`
// field (an index into a swatch list this version no longer has, back when
// notes were pastel and each one picked its own hue). Nothing here reads
// that field any more; it is simply ignored wherever it survives on disk,
// which is enough to keep an old sticky-notes.json loading cleanly with no
// migration step of its own.
Singleton {
    id: root

    property var list: []

    // The default size for every note that has never been resized --
    // StickyNote.qml falls back to these for a note with no w/h field, and
    // `create()` below centres a new note using them, so a fresh note's
    // on-screen size and its placement math can never drift apart.
    readonly property int noteWidth: 176
    readonly property int noteHeight: 160

    // Floor for the resize grip -- small enough to still read as a note, not
    // so small the delete glyph and the grip itself start overlapping.
    readonly property int noteMinWidth: 120
    readonly property int noteMinHeight: 90

    // Which note currently holds the caret, by id. Session state only, never
    // persisted: reopening the shell should never reopen a note mid-edit, and
    // DesktopWidgets.qml reads this (scoped to its own screen) to know when
    // to ask for keyboard focus.
    property string editingId: ""

    // Bound to SUPER+S in hyprland.lua (not owned here): `qs ipc -c rd-shell
    // call stickynotes create`. Click-to-create on the empty desktop used to
    // be how a note got made; it kept appearing by accident from an ordinary
    // double-click meant for something else, so creation moved onto a
    // deliberate keybind instead, gated on the workspace actually being
    // empty rather than on where the pointer happened to be.
    IpcHandler {
        target: "stickynotes"
        function create(): void { root.create(); }
    }

    // Does nothing unless the focused workspace has no windows on it --
    // a note appearing over whatever was already open is exactly the
    // accidental-creation failure mode this replaced the click gesture for,
    // just newly possible again from a keybind if this guard were missing.
    // `Workspaces.windowCount(id)` is id-based and does not care whether the
    // id is a special workspace's (typically negative) one, so a special
    // (scratchpad) workspace is checked, and created on, exactly the same
    // way an ordinary one is -- "empty" means the same thing everywhere.
    //
    // Placement wants the cursor, not just the monitor's centre: a short-
    // lived `hyprctl cursorpos -j` (one process, quick, and the only route
    // to the pointer -- Quickshell.Hyprland itself exposes monitors,
    // workspaces and toplevels, never the pointer position) answers with
    // global desktop coordinates, so `_finishCreate` below converts those
    // into this monitor's own local space before clamping and placing the
    // note. `_pendingCreate` guards against a second SUPER+S landing while
    // that round trip is still in flight.
    property bool _pendingCreate: false

    function create() {
        const ws = Workspaces.focused;
        if (!ws || Workspaces.windowCount(ws.id) > 0) return;

        const mon = ws.monitor;
        if (!mon) return;

        if (root._pendingCreate) return;
        root._pendingCreate = true;

        cursorQuery.mon = mon;
        cursorQuery.command = ["hyprctl", "cursorpos", "-j"];
        cursorQuery.running = true;
    }

    // Runs once `create()`'s cursorpos query has exited, successfully or
    // not. `cx`/`cy` are `null` on any failure (query error, bad/missing
    // JSON) -- centred on the monitor is the fallback for all of those, the
    // same one used before this monitor had a cursor query at all.
    function _finishCreate(mon, cx, cy) {
        root._pendingCreate = false;

        let x, y;
        if (cx !== null && cy !== null) {
            // `hyprctl cursorpos` answers in global desktop coordinates;
            // `mon.x`/`mon.y` is that same monitor's own global offset (DP-1
            // at 0,0, DP-2 at 2560,0 on this machine) -- subtracting one
            // from the other is what turns "somewhere on the desktop" into
            // "somewhere on this monitor's own surface", which is the space
            // every note's x/y already lives in.
            x = cx - mon.x - root.noteWidth / 2;
            y = cy - mon.y - root.noteHeight / 2;
            x = Math.min(Math.max(x, 0), Math.max(0, mon.width - root.noteWidth));
            y = Math.min(Math.max(y, 0), Math.max(0, mon.height - root.noteHeight));
        } else {
            x = Math.max(0, mon.width / 2 - root.noteWidth / 2);
            y = Math.max(0, mon.height / 2 - root.noteHeight / 2);
        }

        root.editingId = root.add(mon.name, x, y);
    }

    Process {
        id: cursorQuery

        property var mon: null
        property string _out: ""

        stdout: StdioCollector {
            onStreamFinished: cursorQuery._out = this.text
        }

        // Read after the process has actually exited, not merely once stdout
        // closes: a failed spawn (hyprctl missing, say) never produces a
        // stream to finish at all, so this is the one signal guaranteed to
        // fire either way and let `_finishCreate` fall back to centred.
        onExited: (exitCode, exitStatus) => {
            let cx = null, cy = null;
            if (exitCode === 0) {
                try {
                    const pos = JSON.parse(cursorQuery._out);
                    if (typeof pos.x === "number" && typeof pos.y === "number") {
                        cx = pos.x;
                        cy = pos.y;
                    }
                } catch (e) {
                    // Malformed/unexpected output -- cx/cy stay null.
                }
            }
            root._finishCreate(cursorQuery.mon, cx, cy);
        }
    }

    // True once this FileView's async load has actually completed at least
    // once. Every Singleton in the shell -- this one included -- gets torn
    // down and rebuilt on any hot reload (any file, not only this one, since
    // it's one qs process for the whole shell), which snaps `list` straight
    // back to its declared `[]` default; `flush` below refuses to write
    // until this is true, specifically so a reload that lands in the instant
    // between that reset and the read actually finishing can never have the
    // freshly-emptied `list` overwrite a sticky-notes.json that still has
    // real notes in it.
    property bool _loaded: false

    FileView {
        id: store

        path: Quickshell.statePath("sticky-notes.json")
        // No file yet just means nobody has ever left a note -- the empty
        // `list` default above already is that state.
        printErrors: false
        onLoaded: {
            root._adopt(store.text());
            root._loaded = true;
        }
        // A missing file reports loadFailed, not loaded -- same as
        // Settings.qml's own FileView. Without this a first-ever session
        // could never write its notes out at all.
        onLoadFailed: root._loaded = true
    }

    function _adopt(text) {
        const parsed = _parse(text);
        if (parsed === null) return;
        if (JSON.stringify(parsed) === JSON.stringify(root.list)) return;
        root.list = parsed;
    }

    function _parse(text) {
        try {
            const saved = JSON.parse(text);
            return Array.isArray(saved) ? saved : null;
        } catch (e) {
            return null;
        }
    }

    // One shared, debounced writer. Dragging a note or typing into one
    // changes `list` on every pixel or every keystroke; the file only needs
    // to catch up once things settle, not on each of those.
    Timer {
        id: flush
        interval: 400
        onTriggered: {
            // The load this singleton's own instance just got hasn't
            // resolved yet -- try again shortly rather than write `list` (at
            // this instant, still whatever it was seeded with, not what's
            // really on disk) over real, unread data. See `_loaded` above.
            if (!root._loaded) { flush.restart(); return; }
            store.setText(JSON.stringify(root.list));
        }
    }

    function _save() {
        flush.restart();
    }

    property int _seq: 0

    function add(screen, x, y) {
        const note = {
            id: `${Date.now()}-${root._seq++}`,
            screen: screen,
            x: x,
            y: y,
            text: "",
            // A few degrees either way -- enough to read as hand-placed,
            // never enough to make the text hard to read.
            rotation: (Math.random() * 6) - 3
        };
        root.list = [...root.list, note];
        root._save();
        return note.id;
    }

    // Shallow-merges `fields` into the one note named by `id`. Every caller
    // (drag, edit) already has the whole note in hand when it wants to
    // change one part of it, so this is the one place that turns "change
    // this field" into a fresh array identity for QML's bindings.
    function update(id, fields) {
        root.list = root.list.map(n => n.id === id ? Object.assign({}, n, fields) : n);
        root._save();
    }

    function remove(id) {
        if (root.editingId === id) root.editingId = "";
        root.list = root.list.filter(n => n.id !== id);
        root._save();
    }

    function forScreen(screen) {
        return root.list.filter(n => n.screen === screen);
    }

    // ── handwritten font ─────────────────────────────────────
    // Picked at runtime against Qt.fontFamilies() rather than hardcoded to
    // whatever `fc-list : family | grep -iE
    // 'hand|script|comic|caveat|kalam|patrick|indie|marker|virgil|excalifont'`
    // turned up on this one machine (only "Comic Mono" -- "Z003" also
    // matches that grep on "script" but is a formal calligraphic chancery
    // face, not a handwritten one, so it is deliberately left off this list
    // rather than preferred over Comic Mono). Checking live means a later
    // install of an actual script face -- Caveat, first in line -- gets
    // picked up the next time the shell starts, with nothing here to update
    // by hand.
    function _pickFont() {
        const prefs = ["Caveat", "Kalam", "Patrick Hand", "Indie Flower", "Comic Neue", "Comic Mono"];
        const available = Qt.fontFamilies();
        for (const name of prefs)
            if (available.indexOf(name) !== -1) return name;
        return Caelus.fontFamily; // nothing hand/script installed -- keep the shell's own
    }

    readonly property string noteFont: _pickFont()
    // Only the fallback wants italic: caelusevka in italic is what read as
    // "handwritten enough" before any of the fonts above were checked for at
    // runtime; an actual script face already looks the part upright.
    readonly property bool noteFontItalic: root.noteFont === Caelus.fontFamily
    // A script/cursive face runs smaller at the x-height than a coding font
    // at the same pixel size -- a couple of points larger is what keeps one
    // of them comfortably legible on a note this size.
    readonly property int noteFontSize: root.noteFontItalic ? 15 : 18
}
