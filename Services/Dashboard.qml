pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Idea corner-islands-notch-dashboard (Round 3): the little plate at the top
// centre of the "corners" bar style and the quick-settings/media/calendar/
// notification panel it drops. Owned by this file alone so the geometry half
// of the round (the plate itself, drawn as a third Blob island -- see
// BarStyles.qml/BarWindow.qml) and the panel half (NotchDashboard.qml, this
// directory) can both code against one small, stable surface from their
// first few minutes rather than discovering each other's shape mid-build.
//
// Mirrors the shape every other toggle-plus-persisted-flag singleton in this
// file's directory already takes (BarStyles.panelOpen/apply, Power.menuOpen,
// Notifications.panelOpen) -- a plain bool plus a toggle function, with the
// one persisted bit (pinned) living on Settings like every other saved
// preference does.
Singleton {
    id: root

    property bool open: false

    function toggle() {
        root.open = !root.open;
    }

    // Whether click-outside dismissal is suspended -- NotchDashboard.qml's
    // own `onDismissed` reads this before acting, the same way a pinned
    // sticky note would ignore a stray click. Escape still closes the panel
    // either way; see the Shortcut in NotchDashboard.qml for why that half
    // can't be read off this flag the same way.
    readonly property bool pinned: Settings.dashboardPinned

    function togglePinned() {
        Settings.dashboardPinned = !Settings.dashboardPinned;
    }

    // The notch tab's own width, in px. Roughly two of the bar's own pills
    // side by side (see BarPopup.qml's comment on pill widths, 20-40px
    // each) -- wide enough for a small glyph without reading as a sliver
    // next to the two corner islands either side of it. Picked once, here,
    // so BarStyles/BarWindow's own geometry and this file's panel both
    // size themselves off the same number instead of two independent
    // guesses that could drift apart.
    readonly property real tabWidth: 64

    // Round 5: the dashboard now opens from a clock right-click in every
    // bar style (BarCenter.qml), not just from the notch tab "corners"
    // alone grows -- so a style switch is no longer the panel leaving its
    // one and only home. The Connections that used to force `open = false`
    // the moment `BarStyles.current` left "corners" is deliberately gone:
    // "pinned" already means "stays open through whatever else happens"
    // everywhere else this flag is read (`togglePinned` above,
    // `onDismissed` in BarOverlays.qml), and a mid-session style switch
    // silently closing it anyway -- pinned or not -- was the one place
    // that promise didn't hold. A panel open when "corners" is switched
    // away from now simply keeps following the clock to wherever
    // `BarOverlays.qml`'s `anchorX` puts it in the new style instead.
    //
    // Nothing above replaces this with a style-keyed reset: there is no
    // style this panel is no longer valid under any more for one to guard.

    // `qs ipc -c rd-shell call dashboard toggle` / `togglePinned` -- same
    // shape as every other IpcHandler-bearing singleton here (see
    // StickyNotes.qml), so this can be driven and tested from a shell
    // command before any keybind or pointer path exists for it.
    IpcHandler {
        target: "dashboard"
        function toggle(): void { root.toggle(); }
        function togglePinned(): void { root.togglePinned(); }
    }
}
