pragma Singleton
import Quickshell
import QtQuick

// The shapes the bar can take, and the switcher overlay that picks between
// them (BarStyleSwitcher.qml, Ctrl+Alt+B). The choice itself is persisted as
// Settings.barStyle; this only knows which ids exist and whether the overlay
// is up.
//
// Adding a style is three edits, one per layer that has to know it: an entry
// in `styles` below, its geometry in BarWindow.qml's `_styleShapes()`, and
// its miniature in BarStyleSwitcher.qml's `Preview` component. Nothing else
// branches on a style id.
Singleton {
    id: root

    // In the order the switcher shows them. `id` is what settings.json stores,
    // so it must never change once shipped; `name` and `description` are only
    // ever read by the switcher's caption.
    readonly property var styles: [
        {
            id: "islands",
            name: "Islands",
            description: "Three floating plates with the wallpaper showing between them"
        },
        {
            id: "full",
            name: "Full bar",
            description: "One solid strip across the whole top edge"
        }
    ]

    // What the bar actually draws. settings.json is a file people edit by
    // hand, so an id no entry answers to -- a typo, or a style some later
    // version removed -- falls back to the first style rather than leaving
    // the bar with no geometry at all.
    readonly property string current: root.styles.some(s => s.id === Settings.barStyle)
        ? Settings.barStyle : root.styles[0].id

    property bool panelOpen: false

    function togglePanel() {
        root.panelOpen = !root.panelOpen;
    }

    // Applying always closes the switcher, the same as picking a wallpaper
    // does; an unknown id is ignored rather than written, for the reason
    // `current` gives above.
    function apply(id) {
        if (root.styles.some(s => s.id === id))
            Settings.barStyle = id;
        root.panelOpen = false;
    }
}
