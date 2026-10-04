pragma Singleton
import Quickshell
import QtQuick

// The settings *window* -- end-4/illogical-impulse's Super+I app, not the
// bar's own quick-toggle popup (SettingsPopup.qml, still the `✦` pill's
// menu). This singleton is the one source of truth for whether that window
// exists, which page it shows, and what the rail is allowed to show in the
// first place: SettingsWindow.qml reads `pages` to build its nav list and
// its page Loader, and shell.qml's `settings` IpcHandler and the live
// Super+I bind in hyprland.lua both only ever call the four functions below.
//
// Deliberately a Singleton, not state owned by SettingsWindow.qml itself:
// the window is torn down to nothing while closed (see shell.qml's
// LazyLoader), so "is it open" and "which page" have to live somewhere that
// survives that -- the same reason Power.menuOpen and Wallpapers.panelOpen
// live in their own services rather than in PowerMenu.qml/WallpaperSwitcher.qml.
Singleton {
    id: root

    // Whether SettingsWindow.qml should exist at all. shell.qml's
    // `LazyLoader { active: SettingsApp.open; SettingsWindow {} }` is the
    // only thing that reads this to create or destroy the window; the window
    // itself only ever reads it to know it is allowed to be up, same as every
    // other on/off flag in this shell (Power.menuOpen, Wallpapers.panelOpen).
    property bool open: false

    // The rail, in the order it is drawn, and the one place that says which
    // page ids exist. `source` is a path SettingsWindow.qml's page Loader
    // reads directly -- relative to that file, so the page QML files sit
    // beside it at the repo root like every other top-level component here.
    // Adding a page later is one entry in this list plus the page file
    // itself; nothing else in this file needs to change.
    readonly property var pages: [
        { id: "look",    name: "Appearance",    icon: "palette",           source: "SettingsLookPage.qml" },
        { id: "bar",     name: "Bar",           icon: "toolbar",           source: "SettingsBarPage.qml" },
        { id: "desktop", name: "Desktop",       icon: "desktop_windows",   source: "SettingsDesktopPage.qml" },
        { id: "access",  name: "Accessibility", icon: "accessibility_new", source: "SettingsAccessPage.qml" },
        { id: "keys",    name: "Keybinds",      icon: "keyboard",          source: "SettingsKeysPage.qml" },
        { id: "about",   name: "About",         icon: "info",              source: "SettingsAboutPage.qml" }
    ]

    // Settings.settingsPage is a plain string on disk -- a hand-edited
    // settings.json, or a page a later version renamed or removed, can name
    // anything -- so this is the one place that validates it against the
    // rail actually on screen and falls back to the first page ("look")
    // for anything else. SettingsWindow.qml's Loader and nav indicator both
    // read this, never Settings.settingsPage directly, so neither has to
    // repeat this check.
    readonly property string page: root.pages.some(p => p.id === Settings.settingsPage)
        ? Settings.settingsPage : "look"

    function toggle() {
        root.open = !root.open;
    }

    // `id` empty or not one of `pages` keeps whatever page is already
    // showing -- the "All settings" row in SettingsPopup.qml wants to open
    // the window on whichever page the reader left it on, not reset it to
    // Appearance every time, while `qs ipc -c rd-shell call settings open
    // bar` wants exactly the opposite. `select()` below already no-ops on an
    // invalid id, so the only thing to guard here is an empty one -- calling
    // it with "" would otherwise fall through to select's own validation and
    // (harmlessly) fail to match any page, but skipping the call entirely
    // reads more clearly than relying on that fallthrough.
    function show(id) {
        root.open = true;
        if (id) root.select(id);
    }

    function select(id) {
        if (root.pages.some(p => p.id === id)) Settings.settingsPage = id;
    }

    function close() {
        root.open = false;
    }
}
