pragma Singleton
import Quickshell
import QtQuick

// The four Hyprland animation presets (hypr/animation-presets.lua) and the
// switcher overlay that picks between them (AnimPresetSwitcher.qml,
// Ctrl+Alt+P). The choice itself is persisted as Settings.animPreset; this
// singleton only knows which ids exist, whether the overlay is up, and how
// to re-assert a pick on the already-running compositor. Same shape as
// Services/BarStyles.qml for the bar style switcher -- read that file's own
// header first if this one is unclear.
//
// Adding a preset is three edits, one per layer that has to know it: an
// entry in `presets` below, its own key in hypr/animation-presets.lua's (and
// its ~/.config/hypr mirror's) `presets` table, and its miniature in
// AnimPresetSwitcher.qml's `Preview` component. Nothing else branches on a
// preset id.
Singleton {
    id: root

    // In the order the switcher shows them. `id` is what settings.json
    // stores and what hyprland.lua's own `require("animation-presets")`
    // table is keyed by, so it must never change once shipped; `name` and
    // `description` are only ever read by the switcher's caption and the
    // settings-app row.
    readonly property var presets: [
        {
            id: "snappy",
            name: "Snappy",
            description: "The same motion as Smooth, just driven harder -- quick, no lingering"
        },
        {
            id: "smooth",
            name: "Smooth",
            description: "The shell's own default feel"
        },
        {
            id: "bouncy",
            name: "Bouncy",
            description: "An overshoot bezier on windows, layers and workspace switches"
        },
        {
            id: "minimal",
            name: "Minimal",
            description: "Reduced motion -- movement turned off, fades only"
        }
    ]

    // What is actually applied. settings.json is a file people edit by hand
    // (and a preset a later version might drop), so an id nothing in
    // `presets` answers to falls back to "smooth" rather than leaving this
    // with nothing to key a card's "applied" mark on -- same fallback shape
    // as Services/BarStyles.qml's own `current`.
    readonly property string current: root.presets.some(p => p.id === Settings.animPreset)
        ? Settings.animPreset : "smooth"

    property bool panelOpen: false

    function togglePanel() {
        root.panelOpen = !root.panelOpen;
    }

    // Applying writes the choice -- hyprland.lua reads this same key back
    // out of settings.json on its own at every config load, see that file's
    // comment on `rd_read_anim_preset` -- and separately re-asserts it on
    // the ALREADY-RUNNING compositor immediately, through `hyprctl eval`
    // calling the exact module hyprland.lua itself required at parse time.
    // That `require` call inside `hyprctl eval` is cheap, not a re-parse of
    // animation-presets.lua: it runs in the same persistent Lua state as
    // the live config (confirmed empirically -- see hyprland.lua's own
    // comment on the probe), and Lua's `require` only ever executes a
    // module's chunk once per state, caching the returned table in
    // `package.loaded` for every call after the first. hyprland.lua's own
    // `require("animation-presets")` at config-load time is what seeds that
    // cache, so this call is just "fetch module.apply, call it" -- it only
    // ever goes stale across a `hyprctl reload`, which gets a fresh Lua
    // state (and so a fresh require) anyway, which is exactly why neither
    // this function nor anything at shell startup needs to replay the
    // preset for Hyprland's benefit on its own; see hyprland.lua.
    //
    // execDetached + `hyprctl eval`, never `hyprctl keyword` -- this shell's
    // Hyprland config is Lua, not the keyword/queue syntax that dispatches,
    // same rule Services/Keybinds.qml's `run()` follows for the same reason.
    //
    // An unknown id is ignored rather than written or dispatched, for the
    // reason `current` gives above; closes the panel either way, the same
    // shape BarStyles.apply()/Wallpapers.apply() have.
    function apply(id) {
        if (root.presets.some(p => p.id === id)) {
            Settings.animPreset = id;
            Quickshell.execDetached(["hyprctl", "eval",
                `require("animation-presets").apply("${id}")`]);
        }
        root.panelOpen = false;
    }
}
