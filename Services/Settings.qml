pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The settings a person actually flips, persisted so a change survives a
// restart instead of reverting to whatever is hand-typed in Config/Caelus.qml.
// SettingsPopup.qml is the panel that writes these; Config/Caelus.qml is what
// reads dynamicColour and scheme back out (roadmap §7.6) -- once both sides
// exist, a toggle here is live immediately through the ordinary property
// bindings on that end, the same as any other reactive value in this shell.
//
// Every property below carries its own default so that a machine with no
// settings.json yet -- the state of things before anyone has ever opened the
// popup -- starts up exactly as it always has, rather than needing the file
// to exist to be safe.
Singleton {
    id: root

    // Aliased straight onto the adapter's own properties rather than mirrored
    // into a second set here: one property is one source of truth, and it is
    // what lets a plain assignment like `Settings.dynamicColour = false` both take
    // effect immediately and be the thing that gets saved, with nothing in
    // between that could disagree.
    property alias dynamicColour: adapter.dynamicColour

    // Which system-popup tab was open last, so reopening the popup -- in this
    // session or the next one, after the shell itself restarts -- lands back
    // where the reader left it instead of always resetting to Processor.
    property alias sysTab: adapter.sysTab

    // Which settings-app rail page was open last (Services/SettingsApp.qml),
    // same reasoning and the same alias-onto-the-adapter pattern as sysTab
    // just above -- reopening the window, this session or the next, lands
    // back on the page the reader left it on rather than always resetting to
    // Appearance. SettingsApp.page is what actually validates this against
    // the live page list and falls back to "look" for anything stale (a page
    // id a future version renamed or removed); this alias only has to carry
    // whatever string was last written.
    property alias settingsPage: adapter.settingsPage

    // Shows or hides DesktopWidgets.qml's whole window (giant clock +
    // now-playing card). On by default, the same reasoning dynamicColour's
    // default gets: a machine that has never opened the settings popup
    // should see the shell as it is meant to look, not a blank desktop layer
    // nobody asked to be off.
    property alias desktopWidgets: adapter.desktopWidgets

    // Idea 9 (Accessibility settings pane): three more presentation-layer
    // toggles, same alias-onto-the-adapter pattern as dynamicColour and
    // desktopWidgets above, so each is its own source of truth and each
    // carries a default that leaves the shell exactly as it looks today.
    //
    // Global scale multiplier Config/Caelus.qml applies to its font-size and
    // spacing tokens. Default 1.0 is the identity case: every token reads
    // exactly the literal it reads today, so a machine that has never opened
    // the popup renders pixel-identical. Range 0.85-1.5 is the slider's job
    // (SettingsPopup.qml), not enforced here.
    property alias uiScale: adapter.uiScale
    // Swaps Config/Colors.qml's text/muted/border/surface tokens for
    // stronger-contrast variants derived from the same matugen/caelus
    // palette. Default false is identical to today's colours.
    property alias highContrast: adapter.highContrast
    // Gates FocusRing.qml's visibility everywhere one is instantiated.
    // Default false: nothing anywhere draws a focus outline until someone
    // turns this on.
    property alias focusRing: adapter.focusRing
    // Shows the bar's Bluetooth pill (it still hides on its own when there is
    // no adapter). Deliberately not in SettingsPopup.qml: it is a set-once
    // choice for a machine that has an adapter but never uses it, so it is
    // set by hand here in settings.json ("bluetoothPill": false).
    property alias bluetoothPill: adapter.bluetoothPill

    // Settings popup -> Wallpaper colours. Off (default) is exactly today's
    // behaviour: matugen runs Config/Caelus.qml's own scheme (tonal-spot),
    // which invents a secondary/tertiary hue rather than staying inside the
    // source colour. On, scripts/matugen-scheme.sh reads this back out of
    // settings.json and swaps in a scheme whose colours stay the wallpaper's
    // own instead.
    property alias wallpaperColours: adapter.wallpaperColours

    // Settings popup -> Keep app colours, directly under wallpaperColours.
    // Only matters once that toggle resolves to matugen's scheme-monochrome
    // (an achromatic wallpaper) -- otherwise every scheme already has real
    // hue and there's nothing to keep. On (default) is the behaviour the
    // user actually asked for: nvim and bat's own syntax highlighting (see
    // matugen/hue.toml) keep a hued scheme even while everything else --
    // the bar, GTK, Qt/KDE, borders, lock, the terminal's ANSI palette,
    // btop, yazi, starship -- goes grey to match the wallpaper. Off follows
    // the wallpaper everywhere, nvim and bat included. scripts/matugen-
    // scheme.sh's `--hue` mode is what actually reads this back out of
    // settings.json.
    property alias keepAppColours: adapter.keepAppColours

    // How a wallpaper swap animates: "random" (default -- a different one
    // every switch) or one transition id to pin. Services/Wallpapers.qml
    // owns which ids exist and falls back to "random" for anything it does
    // not recognise, the same way BarStyles does for barStyle.
    property alias wallpaperTransition: adapter.wallpaperTransition

    // The bar's shape, picked in the Ctrl+Alt+B switcher. Stored as a style
    // id; Services/BarStyles.qml owns which ids exist and falls back to the
    // first one for anything it does not recognise.
    property alias barStyle: adapter.barStyle

    // Workspace dot skin ("dots" | "glyph"), picked in the same Ctrl+Alt+B
    // switcher. Services/BarStyles.qml owns which ids exist and falls back to
    // "dots" for anything else, same as barStyle above.
    property alias workspaceSkin: adapter.workspaceSkin

    // Idea 31: the clipboard-paste ripple. On by default, same reasoning as
    // desktopWidgets above -- a machine that has never opened the settings
    // popup should see the shell as it is meant to look. ClipboardRipple.qml
    // reads this directly (not just to hide the ripple, but to stop its own
    // `wl-paste --watch` process entirely while off -- see that file).
    property alias clipboardRipple: adapter.clipboardRipple

    // Idea corner-islands-notch-dashboard: whether the notch dashboard
    // (Services/Dashboard.qml) ignores click-outside dismissal. Off by
    // default, same reasoning as focusRing and highContrast above -- this is
    // a deliberate per-person choice, not a look the shell should start
    // anyone off with.
    property alias dashboardPinned: adapter.dashboardPinned

    // Settings app -> Appearance -> Wavy OSD progress. On (default), the
    // volume/brightness OSD level bars draw the Material 3 wavy progress
    // (WavyArc.qml); off, the plain filled bar they had before.
    property alias osdWavy: adapter.osdWavy

    // Hyprland's animation feel, picked in the Ctrl+Alt+P switcher
    // (Services/AnimPresets.qml, AnimPresetSwitcher.qml): "snappy" | "smooth"
    // | "bouncy" | "minimal". Default "smooth" is exactly today's hand-typed
    // curves and speeds -- see hypr/animation-presets.lua's own header for
    // why that one has to stay a byte-for-byte match. Services/AnimPresets.qml
    // owns which ids exist and falls back to "smooth" for anything else, the
    // same tolerant-default shape barStyle/workspaceSkin use above. Unlike
    // every other alias here, this one is NOT the single source of truth for
    // what the compositor is actually doing: hyprland.lua reads this same key
    // straight out of settings.json on its own, at every config load
    // (reload or restart) -- see that file's comment on why -- so this value
    // and the live Hyprland animation state can disagree only for the instant
    // between a write here landing on disk and the `hyprctl eval` that
    // follows it (AnimPresets.apply()) actually running.
    property alias animPreset: adapter.animPreset

    // Round 4 (settings-app Bar page additions) below. Same alias-onto-the-
    // adapter pattern and the same "default equals today's behaviour" rule
    // as everything above -- a machine with no settings.json yet starts up
    // pixel- and sound-identical to before any of these existed.

    // Services/Time.qml's clock format: "24h" (default, today's hard-coded
    // "HH:mm") or "12h". Deliberately global rather than bar-only: Time.qml
    // is the one singleton the bar pill, the desktop clock (DesktopClock.qml)
    // and the lock screen (LockSurface.qml) all read, and letting the bar
    // read 24h while the lock screen reads 12h would look like a bug, not a
    // feature -- the control just happens to live on the Bar settings page,
    // since that is where a person goes looking for "the clock".
    property alias clockFormat: adapter.clockFormat
    // Appends seconds to the same clock. Off (default) keeps Time.qml's
    // SystemClock at its current Minutes precision; Time.qml only drops to
    // Seconds precision while this is actually on, so a machine that never
    // touches this setting gets no extra per-second wakeups it didn't have
    // before.
    property alias clockSeconds: adapter.clockSeconds

    // Promotes Config/Caelus.qml's workspaceBeatGlow to a real toggle, the
    // same way dynamicColour/uiScale are read back out of this file -- see
    // Caelus.qml's own comment on the property for what it does. Default
    // false matches Caelus.qml's own literal default exactly.
    property alias workspaceBeatGlow: adapter.workspaceBeatGlow

    // Pill visibility toggles, same shape as bluetoothPill above: each pill
    // already hides itself on its own underlying condition (no tray icons,
    // SysMon unavailable, ...) and these just add a person's own override on
    // top, same as bluetoothPill's adapter does for the Bluetooth pill. All
    // default true -- exactly today's unconditional/self-gated visibility --
    // so nothing disappears from the bar until someone opens this page.
    property alias trayPill: adapter.trayPill
    property alias cavaPill: adapter.cavaPill
    property alias systemPill: adapter.systemPill
    property alias networkPill: adapter.networkPill

    // Bar edge margin (0-24px) and surface opacity (0.30-0.70), both read
    // back out of Config/Caelus.qml's barMargin/opacitySurface the same way
    // uiScale is -- see that file for the clamp (settings.json is hand-
    // editable, so the clamp lives there too, not just in this page's
    // slider). Defaults are Caelus.qml's own pre-existing literals (14,
    // 0.45), so a fresh settings.json changes nothing about how the bar
    // looks.
    property alias barMargin: adapter.barMargin
    property alias barOpacity: adapter.barOpacity

    // Pill.qml's press-origin ink (RippleLayer.qml). On (default) is exactly
    // what shipped this round; off, Pill falls back to the flat press wash
    // it always had before the ripple existed.
    property alias pillRipple: adapter.pillRipple

    // Round 5 (calendar-reminders-rework), Desktop page. CalendarGrid.qml's
    // own two display choices -- which day starts the week ("monday",
    // default, matching the grid's original hand-written Monday-first lead
    // calculation exactly, or "sunday") and whether to print an ISO week
    // number beside each row (off by default: nothing drew one before this
    // existed). Same alias-onto-the-adapter pattern as every property above.
    property alias weekStart: adapter.weekStart
    property alias weekNumbers: adapter.weekNumbers

    // The shell's own config symlink -- ~/.config/quickshell/rd-shell points
    // at this repo -- so settings.json lands beside every other file here
    // rather than in some second, hidden location a person would have to be
    // told about separately.
    readonly property string _dir: `${Quickshell.env("HOME")}/.config/quickshell/rd-shell`

    // Idempotent and fire-and-forget, so it costs nothing on every one of the
    // countless runs where this directory -- the shell's own config symlink --
    // already exists, and is what keeps the first-ever write from failing
    // silently on a machine where it does not.
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root._dir])

    // Turning dynamic colour on or off used to change nothing anyone could see
    // until the next wallpaper switch, because matugen is what paints the
    // theme and nothing ever re-ran it. `--restore` re-applies the wallpaper
    // already in use, which is exactly the "render the theme again" step that
    // was missing, without asking anyone to choose a picture twice.
    //
    // Guarded on `_ready` so the first load of settings.json -- which changes
    // these properties from their declared defaults to whatever is saved --
    // does not re-render the theme on every single shell start.
    property bool _ready: false

    // The same flag, read-only for everyone else: a value that changes before
    // this is true is settings.json arriving, not a person changing it.
    readonly property bool ready: root._ready

    onDynamicColourChanged: if (root._ready) reapplyDebounce.restart()

    // Same reasoning as dynamicColour above: the scheme matugen renders with
    // is baked into the last render, so flipping this needs the same
    // re-render to be seen rather than waiting for the next wallpaper pick.
    onWallpaperColoursChanged: if (root._ready) reapplyDebounce.restart()

    // Same reasoning again: matugen/hue.toml's own scheme is baked into the
    // last render too, so this needs the same re-render as the two above.
    onKeepAppColoursChanged: if (root._ready) reapplyDebounce.restart()

    // matugen reads settings.json, and JsonAdapter writes it a moment after the
    // property changes. Re-rendering immediately would read the old scheme back
    // and repaint the theme it already had; the delay is there to let the write
    // land first. It also collapses a burst of clicks through the chip row into
    // one matugen run rather than one per chip touched on the way past.
    Timer {
        id: reapplyDebounce

        interval: 400
        onTriggered: reapplyTheme.running = true
    }

    Process {
        id: reapplyTheme

        command: [`${root._dir}/scripts/wallpaper-apply.sh`, "--restore"]
    }

    FileView {
        id: store

        path: `${root._dir}/settings.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._ready = true

        // FileNotFound here means only that nobody has saved a setting since
        // install -- JsonAdapter's own declared defaults below already stand
        // in for that file, so there is nothing to correct. Quiet rather than
        // logged.
        printErrors: false
        onLoadFailed: root._ready = true

        // JsonAdapter, not a hand-rolled JSON.stringify() of these three
        // properties: it reads back only the keys it declares and leaves
        // every other key already on disk untouched when it writes, so a
        // future version's fourth setting -- or any other tool that shares
        // this file -- survives being saved by a build that predates it.
        // (Services/Reminders.qml's store is deliberately the other way:
        // plain JSON, because that file is single-writer and wants a save
        // that lands in the same frame as the change, which an adapter's
        // change-coalescing does not guarantee.)
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            property bool dynamicColour: true
            property string sysTab: "cpu"
            property string settingsPage: "look"
            property bool desktopWidgets: true
            property real uiScale: 1.0
            property bool highContrast: false
            property bool focusRing: false
            property bool bluetoothPill: true
            property bool wallpaperColours: false
            property bool keepAppColours: true
            property string wallpaperTransition: "random"
            property string barStyle: "islands"
            property string workspaceSkin: "dots"
            property bool clipboardRipple: true
            property bool dashboardPinned: false
            property bool osdWavy: true
            property string animPreset: "smooth"
            property string clockFormat: "24h"
            property bool clockSeconds: false
            property bool workspaceBeatGlow: false
            property bool trayPill: true
            property bool cavaPill: true
            property bool systemPill: true
            property bool networkPill: true
            property int barMargin: 14
            property real barOpacity: 0.45
            property bool pillRipple: true
            property string weekStart: "monday"
            property bool weekNumbers: false
        }
    }
}
