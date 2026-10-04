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
        },
        {
            id: "corners",
            name: "Corner dashboard",
            description: "Two corner islands and a notch that drops the dashboard"
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

    // ── workspace dot skin ───────────────────────────────────
    // A second, independent choice from the bar shape above: whether
    // WorkspaceDots.qml paints each occupied slot as a plain dot (today's
    // look, "dots") or as its workspace number inside the same ring
    // ("glyph"). Same id/name/description shape as `styles` above, and the
    // same rule: `id` is what gets persisted, so it must never change once
    // shipped.
    readonly property var workspaceSkins: [
        {
            id: "dots",
            name: "Dots",
            description: "A plain dot per workspace (today's look)"
        },
        {
            id: "glyph",
            name: "Glyph numerals",
            description: "Each occupied workspace shows its number instead of an icon"
        }
    ]

    // Same fallback shape as `current` above: an id nothing in
    // `workspaceSkins` answers to -- hand-edited state, or a skin a later
    // version dropped -- reads back as the first skin ("dots") rather than
    // leaving WorkspaceDots.qml with nothing to key its default branch on.
    readonly property string workspaceSkin: root.workspaceSkins.some(s => s.id === Settings.workspaceSkin)
        ? Settings.workspaceSkin : root.workspaceSkins[0].id

    // Mirrors `apply()` above: an unknown id is ignored rather than
    // written, since `workspaceSkin`'s own fallback would otherwise mask a
    // typo silently instead of refusing it here.
    function applyWorkspaceSkin(id) {
        if (root.workspaceSkins.some(s => s.id === id))
            Settings.workspaceSkin = id;
    }
}
