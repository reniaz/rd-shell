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

    // Shows or hides DesktopWidgets.qml's whole window (giant clock +
    // now-playing card). On by default, the same reasoning dynamicColour's
    // default gets: a machine that has never opened the settings popup
    // should see the shell as it is meant to look, not a blank desktop layer
    // nobody asked to be off.
    property alias desktopWidgets: adapter.desktopWidgets

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

    onDynamicColourChanged: if (root._ready) reapplyDebounce.restart()

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
        // logged, the same call Services/Dzuma.qml makes for its own
        // not-yet-run state file.
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
            property bool desktopWidgets: true
        }
    }
}
