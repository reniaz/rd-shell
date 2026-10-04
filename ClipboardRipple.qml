import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.Config
import qs.Services

// Idea 31: a one-frame confirmation that something just landed on the
// clipboard -- a faint accent halo and hairline ring opening at the cursor
// around a fading dot, gone in about 400ms. Two triggers:
//   - copy: `wl-paste --watch` reports every clipboard *change*.
//   - paste: Wayland has no event for an app *reading* the clipboard, so
//     paste is caught at the keyboard instead -- Hyprland binds Ctrl+V and
//     Ctrl+Shift+V (terminals) as non_consuming globals in hyprland.lua,
//     the key still reaches the app, and `pasteShortcut` below hears it.
//     Deliberate: a paste from a menu or middle-click has no key to catch
//     and does not ripple.
//
// ---- one window, not one per event ----
// Every other OSD in this shell (KeyboardLayoutOsd, AudioOsd, BrightnessOsd)
// is built, shown and torn down per event through a PopupLoader living in
// BarOverlays.qml -- but that file (and BarWindow.qml, which is the only
// thing that instantiates BarOverlays) belongs to a different piece of this
// round's work, and "register only in shell.qml" is this file's own
// contract. So this follows the *other* half of what this codebase already
// does for a full-screen layer that only cares about the focused monitor at
// the moment it is asked for something -- WlLock.qml's WlSessionLock and
// DesktopWidgets' per-screen windows both stay mapped for the shell's whole
// life and are driven purely by property changes, never rebuilt. A ripple
// fires far more often than an OSD (every copy, not every explicit action),
// so "create a window, wait for a hold timer, destroy it" per event is
// exactly the loader churn the roadmap's own OSD work moved away from where
// it could -- one window object, created once, is what actually makes
// "no leaked window on repeated clipboard changes" a non-question: nothing
// is ever created or destroyed after Component.onCompleted, so there is
// nothing left to leak. Deliberate: its layer surface is only *mapped*
// while a ripple plays (`visible: root._active`). An idle, always-mapped
// full-screen overlay -- even a transparent, click-through one -- sits above
// fullscreen windows and costs Hyprland direct scanout/tearing there; a
// map/unmap per copy is cheap by comparison.
//
// The window is anchored full-screen on whatever monitor was focused the
// moment the ripple fired (see `_placeAndFire` below) and re-targeted there
// every time -- "per the focused screen" without needing a Variants block
// over every screen (which would be N overlay surfaces instead of one).
PanelWindow {
    id: root

    // Settings.clipboardRipple (Services/Settings.qml) gates the whole
    // feature, including the wl-paste process itself -- see `_startWatcher`/
    // `_stopWatcher` below. The window keeps existing either way (nothing to
    // leak by toggling it), it just never has anything to show while off.
    property bool _firstEventSeen: false
    property bool _queryBusy: false
    property bool _queryStale: false
    property bool _active: false
    property point localPos: Qt.point(0, 0)

    // Deliberate: subtle on purpose -- a soft tint and a hairline, never a
    // target. First pass (120px bordered rings, a solid 24px core pulsing
    // twice) read as loud and dated. Now the widest layer stops at 44px,
    // nothing has a solid fill above 18% alpha except a 6px dot that only
    // fades, and there is one outward beat, no pulse.
    readonly property real _haloStart: 6
    readonly property real _haloEnd: 44
    readonly property real _ringStart: 6
    readonly property real _ringEnd: 30
    readonly property real _coreSize: 6

    // Composed from Config/Motion.qml tokens, no bespoke numbers: halo
    // Motion.slow + Motion.base (390ms, the whole ripple), ring
    // Motion.base + Motion.fast (290ms) so the two layers separate as they
    // grow, core Motion.slow (220ms).
    readonly property int _haloMs: Motion.slow + Motion.base
    readonly property int _ringMs: Motion.base + Motion.fast

    screen: Quickshell.screens[0] ?? null

    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-clipboardripple"
    color: "transparent"

    // Deliberate: always an empty Region, never `null`. This window covers
    // the whole screen whenever it is mapped, so unlike WallpaperSwitcher
    // (which only wants to accept input while it is actually up) there is no
    // state this should ever accept a click in -- it reports a copy that has
    // already happened, same reasoning as every OSD's own `mask: Region {}`.
    mask: Region {}

    visible: root._active

    // ---- wl-paste watcher ----
    //
    // `Process.running` is a real two-way property: Quickshell sets it back
    // to false itself the moment the child exits, which would silently and
    // permanently clear a declarative `running: Settings.clipboardRipple`
    // binding the first time wl-paste ever restarted (a plain property
    // write -- from QML or from native code -- always drops an active
    // binding on that property). So this is deliberately never bound: the
    // setting is read explicitly wherever the process is started or
    // stopped, mirroring Services/DiscordCall.qml's own bridge-process
    // restart, which has the same shape for the same reason.
    Process {
        id: watcher

        // `wl-paste --watch echo x` -- one line of output per clipboard
        // change, and nothing else. No helper script: `echo x` is the
        // command wl-paste re-runs on every change, and its stdout is
        // wl-paste's own stdout, which is all `stdout: SplitParser` below
        // needs to see.
        //
        // Deliberate: wrapped in `setpriv --pdeathsig TERM`. wl-paste never
        // writes to that stdout itself (only the `echo` it spawns does), so
        // nothing tells it the shell is gone -- a killed or restarted shell
        // left the old watcher running under systemd --user forever, one
        // more per restart. The parent-death signal ends it with the shell.
        command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--watch", "echo", "x"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._onClipboardLine()
        }

        // wl-paste can exit on its own (a compositor restart, the clipboard
        // manager hiccuping) -- restarted here as long as the setting is
        // still on. Never races `_stopWatcher()`: turning the setting off
        // sets `running` false itself, which is a normal stop, not an
        // exit this handler needs to second-guess.
        onExited: (exitCode, exitStatus) => {
            if (Settings.clipboardRipple)
                restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 750
        onTriggered: root._startWatcher()
    }

    function _startWatcher() {
        // A freshly (re)started wl-paste always announces the clipboard's
        // current contents on the very first line, before anything has
        // actually been copied since -- see `_onClipboardLine` below.
        root._firstEventSeen = false;
        watcher.running = true;
    }

    function _stopWatcher() {
        restartTimer.stop();
        watcher.running = false;
    }

    Connections {
        target: Settings
        function onClipboardRippleChanged() {
            if (Settings.clipboardRipple) root._startWatcher();
            else root._stopWatcher();
        }
    }

    Component.onCompleted: if (Settings.clipboardRipple) root._startWatcher();

    function _onClipboardLine() {
        // Deliberate: `wl-paste --watch <cmd>` runs <cmd> once immediately
        // on start to report whatever is already on the clipboard, before
        // watching for the next real change -- confirmed by observation
        // (the very first ripple after every shell reload fired with no
        // copy having happened). Swallowing exactly one line per
        // (re)start, not just at shell startup, is what keeps a wl-paste
        // restart from reading as a phantom paste too.
        if (!root._firstEventSeen) {
            root._firstEventSeen = true;
            return;
        }
        root._request();
    }

    // Hyprland's `hl.dsp.global("quickshell:clipboardPaste")` on Ctrl+V and
    // Ctrl+Shift+V, bound non_consuming so the paste itself still happens.
    GlobalShortcut {
        id: pasteShortcut

        name: "clipboardPaste"
        description: "Clipboard ripple on paste"
        onPressed: if (Settings.clipboardRipple) root._request();
    }

    function _request() {
        // A query already in flight covers whichever copy comes back
        // first; a copy that lands while it is still running is not lost,
        // it just asks for one more query once the first resolves (see
        // `_onCursorPos`) rather than piling up a Process per keystroke of
        // a rapid-fire burst.
        if (root._queryBusy) {
            root._queryStale = true;
            return;
        }
        root._queryBusy = true;
        cursorQuery.running = true;
    }

    // One-shot per fire, the same idiom Services/StickyNotes.qml's own
    // `cursorQuery` uses: Quickshell.Hyprland exposes monitors, workspaces
    // and toplevels, but never the pointer position, so `hyprctl cursorpos
    // -j` is the only route to it.
    Process {
        id: cursorQuery
        command: ["hyprctl", "cursorpos", "-j"]

        stdout: StdioCollector {
            onStreamFinished: root._onCursorPos(this.text)
        }
    }

    function _onCursorPos(text) {
        root._queryBusy = false;

        if (root._queryStale) {
            // A newer copy landed mid-query; re-run rather than animate at
            // a cursor position that may already be stale by the time this
            // one's answer arrived.
            root._queryStale = false;
            root._queryBusy = true;
            cursorQuery.running = true;
            return;
        }

        let pos = null;
        try { pos = JSON.parse(text); } catch (e) { /* malformed/empty -- skip this one */ }
        if (!pos || typeof pos.x !== "number" || typeof pos.y !== "number")
            return;

        root._placeAndFire(pos.x, pos.y);
    }

    // Targets the monitor that is focused right now, not whichever one this
    // window happened to be on last -- the same "focused wins, with a
    // fallback" rule BarWindow.qml's own `overlayScreen` follows.
    function _placeAndFire(globalX, globalY) {
        const name = Hyprland.focusedMonitor?.name ?? "";
        const target = Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
        if (!target) return;

        if (root.screen !== target) root.screen = target;

        // `hyprctl cursorpos` answers in global desktop coordinates;
        // `target.x`/`target.y` is that monitor's own global offset -- the
        // same conversion Services/StickyNotes.qml does for the same
        // reason. Clamped so a cursor that raced across a monitor edge
        // between the query firing and landing still places inside it.
        const lx = Math.min(Math.max(globalX - target.x, 0), target.width);
        const ly = Math.min(Math.max(globalY - target.y, 0), target.height);
        root.localPos = Qt.point(lx, ly);

        root._fire();
    }

    function _fire() {
        fireAnim.stop();
        root._active = true;

        // Reset every animated value before replaying: stopping a running
        // ParallelAnimation leaves each property wherever it was, and a
        // rapid-fire burst would otherwise restart from a half-faded ripple.
        halo.width = root._haloStart;
        halo.opacity = 1;
        ring.width = root._ringStart;
        ring.opacity = 1;
        core.scale = 1;
        core.opacity = 0.7;

        fireAnim.start();
    }

    Item {
        id: stage

        anchors.fill: parent

        // `height`/`x`/`y` bind off `width` on every layer, so animating
        // `width` alone keeps each one a circle centred on the cursor.
        //
        // Deliberate: every colour is `Colors.accent` (Config/Colors.qml),
        // which is `Wal.accent` under dynamic colour -- the ripple re-tints
        // with the wallpaper for free. One hue at different strengths reads
        // calmer than the accent/accentBright pair the first pass used.

        // Halo: a soft tinted disc, no edge.
        Rectangle {
            id: halo

            width: root._haloStart
            height: width
            x: root.localPos.x - width / 2
            y: root.localPos.y - height / 2
            radius: width / 2
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.18)
            opacity: 0
        }

        // Ring: a 1px hairline, quicker than the halo.
        Rectangle {
            id: ring

            width: root._ringStart
            height: width
            x: root.localPos.x - width / 2
            y: root.localPos.y - height / 2
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.6)
            opacity: 0
        }

        // Core: a small dot at the cursor that shrinks away as it fades.
        Rectangle {
            id: core

            width: root._coreSize
            height: root._coreSize
            x: root.localPos.x - width / 2
            y: root.localPos.y - height / 2
            radius: width / 2
            color: Colors.accent
            opacity: 0
        }
    }

    ParallelAnimation {
        id: fireAnim

        NumberAnimation {
            target: halo; property: "width"
            to: root._haloEnd; duration: root._haloMs
            easing.type: Motion.standard
        }
        NumberAnimation {
            target: halo; property: "opacity"
            to: 0; duration: root._haloMs
            easing.type: Motion.standard
        }

        NumberAnimation {
            target: ring; property: "width"
            to: root._ringEnd; duration: root._ringMs
            easing.type: Motion.standard
        }
        NumberAnimation {
            target: ring; property: "opacity"
            to: 0; duration: root._ringMs
            easing.type: Motion.standard
        }

        ScaleAnimator { target: core; to: 0.4; duration: Motion.slow; easing.type: Motion.standard }
        NumberAnimation { target: core; property: "opacity"; to: 0; duration: Motion.slow; easing.type: Motion.standard }

        // Unmaps the window (`visible: root._active`) once every layer has
        // finished, so the next `_fire()` never collides with a running one.
        onStopped: root._active = false
    }
}
