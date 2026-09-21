pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property var list: Hyprland.workspaces.values
    readonly property HyprlandWorkspace focused: Hyprland.focusedWorkspace
    readonly property int focusedId: focused?.id ?? -1
    readonly property string focusedName: focused?.name ?? ""

    // The dot row for one monitor, memoised per monitor. Nothing binds to this,
    // so mutating it in place is deliberate -- it must not itself count as a
    // change and re-trigger the bindings that read through dotsFor().
    property var _dots: ({})

    // Hyprland creates and destroys empty workspaces as you move between them,
    // so `list` is re-published by the very act of switching. A fresh array out
    // of here on every one of those is a new model for the Repeater in
    // WorkspaceDots, which throws away every dot and builds it again -- and a
    // Behavior never fires for a value a property was *created* with, so the dot
    // for the workspace you just moved to appears already wide instead of
    // growing into it. Returning the previous array whenever it holds the same
    // workspaces, in the same order, is what lets that animation play: the
    // delegates survive, and the ones that must change do so by binding.
    function dotsFor(monitor) {
        const name = monitor?.name ?? "";
        const next = list
            .filter(w => w.id > 0 && w.monitor?.name === monitor?.name)
            .sort((a, b) => a.id - b.id);

        // Compared by object identity rather than by id: Hyprland handing back a
        // rebuilt object for the same workspace number has to count as a change,
        // or the Repeater would be left holding one that no longer exists.
        const prev = root._dots[name];
        if (prev && prev.length === next.length && prev.every((w, i) => w === next[i]))
            return prev;

        root._dots[name] = next;
        return next;
    }

    // Windows on the focused workspace that you cannot see, because one of them
    // is fullscreen or faking it and is covering the rest.
    readonly property bool focusedCovered: root._covered
    readonly property int focusedHidden: root._covered
        ? Math.max(0, root.windowCount(root.focusedId) - 1)
        : 0

    // Read back from Hyprland rather than taken from the event that announced
    // the change. The `fullscreen` event carries a state, but not one that can
    // be believed on its own: a single toggle emits a 0 immediately followed
    // by a 1 when a window moves between fullscreen modes, so the last value
    // to arrive is not the state the window ended in. The event is a good
    // signal that something moved and a bad account of what.
    //
    // The listing is the account, and asking for it is a round trip that is
    // not answered in the same turn -- which is why this re-reads a few times
    // rather than once. Four reads 130ms apart cost nothing at the rate anyone
    // toggles fullscreen, and by the end of them the answer has stopped
    // moving.
    property bool _covered: false

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            switch (event.name) {
            case "fullscreen":
            case "workspace":
            case "workspacev2":
            case "focusedmon":
            case "closewindow":
            // Everything from here down announces a workspace, a monitor or a
            // window the listing may not hold yet. The session starts the
            // shell while the second monitor is still coming up, so the
            // workspaces pinned to it -- and the windows autostart opens on
            // them -- are announced to a shell whose listing was taken before
            // any of them existed. Quickshell says so ("Got openwindow for
            // workspace 9 which was not previously tracked") and then carries
            // a window that belongs to no workspace: that monitor's dots are
            // missing and the apps it started count for nothing.
            case "createworkspace":
            case "createworkspacev2":
            case "destroyworkspace":
            case "destroyworkspacev2":
            case "moveworkspace":
            case "moveworkspacev2":
            case "monitoradded":
            case "monitoraddedv2":
            case "monitorremoved":
            case "openwindow":
            case "movewindow":
            case "movewindowv2":
                resync.restart();
                break;
            }
        }
    }

    Timer {
        id: resync

        property int shots: 0

        interval: 130
        repeat: true
        triggeredOnStart: true
        onRunningChanged: if (running) resync.shots = 0
        onTriggered: {
            // Reads what the previous pass asked for and asks again, so the
            // last read is answering a request made after the event.
            root._covered = root.focused?.lastIpcObject?.hasfullscreen ?? false;
            root.reload();
            if (++resync.shots >= 4) resync.stop();
        }
    }

    // Every refresh in this file goes through here, and none of them happens
    // before Quickshell has a listing of its own.
    //
    // The models fill themselves the first time anything reads them, over the
    // same socket a refresh asks on. A refresh that gets in before that does
    // not start it early -- it answers instead of it, and what comes back that
    // early holds only the workspaces that something is sitting on: the two
    // being looked at, the scratchpads, and whatever has a window. The empty
    // ones are dropped, and no later refresh puts them back, so the dot row
    // spends the session missing every workspace nothing has opened yet --
    // until you visit one, and the event that follows adds that one alone.
    //
    // Reading the length is what starts the listing, so the first call through
    // here does nothing except set that going.
    function reload() {
        if (Hyprland.workspaces.values.length === 0) return;

        Hyprland.refreshWorkspaces();
        // Asked for after the workspaces, not instead of them: a window whose
        // workspace was unknown when it opened is only put back on one by a
        // listing taken while that workspace is in the model.
        Hyprland.refreshToplevels();
    }

    Component.onCompleted: resync.restart()

    // Whether what Hyprland has told us so far hangs together: every monitor
    // owns at least one workspace, every workspace sits on a monitor, and
    // every window sits on a workspace. None of that is true while the
    // session is still starting, and no event says when it finally becomes
    // true -- the events that would have said so are the ones that arrived
    // too early. A workspace announced by `createworkspace` in particular
    // arrives as a bare id with no monitor on it, which is invisible to a dot
    // row that asks each workspace which monitor it is on.
    readonly property bool tracked: Hyprland.monitors.values.length > 0
        && Hyprland.monitors.values.every(m => root.list.some(w => w.monitor === m))
        && root.list.every(w => w.monitor)
        && Hyprland.toplevels.values.every(t => t.workspace)

    // So the listing is simply asked for again until it stops contradicting
    // itself. Events cover every change once the session is up; this covers
    // the one thing they cannot, a listing that was already stale when it was
    // taken. It stops the moment the answer holds together, and stops anyway
    // after half a minute: a monitor with no workspace that long after login
    // is a real state, not a race.
    Timer {
        id: catchup

        property int shots: 0

        interval: 500
        repeat: true
        running: !root.tracked && catchup.shots < 60
        onTriggered: {
            ++catchup.shots;
            Hyprland.refreshMonitors();
            root.reload();
        }
    }

    function windowCount(id) {
        return Hyprland.toplevels.values.filter(t => t.workspace?.id === id).length;
    }

    function _ws(w) {
        return typeof w === "number" ? w : `"${w}"`;
    }

    // Drops whatever is covering the workspace back into the stack.
    //
    // A toggle rather than one of the Lua API's `set`/`unset` actions, which
    // take a mask and do not mean "off": asked to unset, a maximized window
    // stayed maximized. There is no ambiguity in toggling here because this is
    // only ever reachable from the badge, and the badge only exists while
    // something is covering the workspace.
    function uncover() {
        if (Hyprland.usingLua)
            Hyprland.dispatch('hl.dsp.window.fullscreen_state({ action = "toggle", internal = 1, client = 0 })');
        else
            Hyprland.dispatch("fullscreen 1");
    }

    function switchTo(w) {
        if (Hyprland.usingLua) Hyprland.dispatch(`hl.dsp.focus({ workspace = ${_ws(w)}})`);
        else Hyprland.dispatch(`workspace ${w}`);
    }

    function moveTo(w) { 
        if (Hyprland.usingLua) Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${_ws(w)}})`);
        else Hyprland.dispatch(`movetoworkspace ${w}`);
    }

    // Raises one window and goes to it, wherever something in the bar knows
    // which window it means. Dispatched the same way the workspace calls above
    // are, and for the same reason: under a Lua config every dispatch is
    // evaluated as Lua source, so the native `focuswindow address:0x...` is a
    // syntax error there -- Lua reads `address:0x...` as a method call and
    // rejects it -- whether it is sent through Hyprland.dispatch or through
    // hyprctl. hl.dsp.focus also carries the workspace switch, so one call both
    // raises the window and takes you to it.
    // Hyprland only answers to the 0x form, and half the places an address comes
    // from have already dropped the prefix: HyprlandToplevel.address is bare,
    // hyprctl prints it either way. Put back rather than required, so no caller
    // has to know which kind it is holding.
    function focusWindow(address) {
        if (!address || address === "") return;

        const target = address.startsWith("0x") ? address : `0x${address}`;
        if (Hyprland.usingLua) Hyprland.dispatch(`hl.dsp.focus({ window = "address:${target}" })`);
        else Hyprland.dispatch(`focuswindow address:${target}`);
    }

    function relative(monitor, delta) {
        const dots = dotsFor(monitor);
        if (dots.length === 0) return;

        const i = dots.findIndex(w => w.id === monitor?.activeWorkspace?.id);
        switchTo(dots[(i + delta + dots.length) % dots.length].id);
    }
}
