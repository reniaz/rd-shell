import QtQuick
import qs.Config

// A Loader that lets the popup it holds finish leaving before it takes the
// popup away.
//
// This used to be built on Quickshell's own `LazyLoader` (`Quickshell/
// LazyLoader`), and that worked as long as every popup it held was itself a
// window: `LazyLoader.item` is typed as a plain `QObject`, not an `Item`, and
// it never parents what it creates into anything -- fine for a `PanelWindow`,
// which is a top-level surface with no `Item` parent to begin with, and
// exactly why this file never had to think about it. Tier 3 turns every
// in-scope popup into an `Item`, and an `Item` built with no parent is not
// merely unpositioned, it is never added to any scene graph at all --
// created, bound, immediately invisible. Swapping to `QtQuick.Loader` is the
// fix: a `Loader` *is* an `Item`, so whatever it creates becomes a real child
// of it, sized by the `anchors.fill: parent` below, and it keeps working
// unmodified for the handful of call sites in BarOverlays.qml that still
// load an actual window through this same file (`KeyboardLayoutOsd`,
// `AudioOsd`, `BrightnessOsd`, `NotificationPopups` -- these stay their own
// windows rather than folding into the fused surface) -- `Loader` has the
// same carve-out `LazyLoader` did for a `Component` whose root is a
// `Window`: it is shown as its own top-level surface rather than forced
// into the tree.
//
// The public surface is unchanged on purpose -- `open`, `active`, `item`,
// the default-property popup content -- so every call site in
// BarOverlays.qml still reads exactly as it did before this file existed in
// its new form.
//
// The delay deliberately does not live in BarPopup, tempting as that is --
// the card is the one thing that knows how long its own animation runs for.
// But a popup cannot outlive a decision its loader has already made: by the
// time the card could react to being closed, `active` has gone false and it
// no longer exists. The loader is the only object in the chain that is alive
// both while the popup is up and after it has been told to shut, so the
// hold belongs here, and the duration is written down here with it.
//
// It also makes the two shapes of open state look the same from
// BarOverlays.qml. Some popups are held open by a Pill, because which bar
// you clicked is the whole question and a second monitor's pill has its own
// answer; others by a service, because Escape, a keybind and the pill must
// all shut one panel. Either way it is one bool, handed to `open` below, and
// this file does not care which.
Loader {
    id: root

    // Overrides `Item`'s own default property (`data`) so a call site can
    // still write `PopupLoader { SomePopup { ... } }` the way it did against
    // `LazyLoader`'s `component` property -- QML wraps an inline object
    // literal assigned to a `Component`-typed property in an implicit
    // `Component` automatically, the same trick every other `sourceComponent:
    // SomeItem { ... }` in this shell already leans on (see Surface.qml's
    // `grainPass` Loader, or ClaudeSessionRow.qml's `detail` one). Named
    // `component` and not `content`, which `BarPopup` already uses for a
    // different thing one property away -- this is the Component the popup
    // is built from, not the Item its own body gets built inside.
    default property Component component
    sourceComponent: root.component

    // Fills whatever this loader was declared inside -- BarOverlays.qml's
    // root Item, itself the full size of the fused window (see
    // BarWindow.qml). A loaded `Item` is not auto-resized by its `Loader`
    // parent on its own; it has to ask for its parent's size itself, which
    // is exactly what every in-scope popup's own `anchors.fill: parent` (see
    // BarPopup.qml) does once this Loader is that parent. A loaded `Window`
    // ignores this anchor entirely, same as it always ignored being inside a
    // non-visual `LazyLoader`.
    anchors.fill: parent

    // Every in-scope popup is a full-window `Item` now, all of them declared
    // as siblings inside BarOverlays.qml's root -- and every `PopupLoader`
    // here is *that* Item's actual sibling, the level Qt Quick's z-ordering
    // acts at, not the popup it loads. `BarPopup` stamps its own `z` with
    // the moment it last opened (see `_zStamp` there) so the most recently
    // opened one always sits on top of any other one still open -- the same
    // policy `focus: root.open` already gives the keyboard. Mirroring that
    // stamp up onto this Loader is what actually makes it count: two
    // `BarPopup`s in two different `PopupLoader`s are never real siblings of
    // each other, so a `z` set on the popup itself would only ever reorder
    // it against nothing. `?? 0` is exactly today's implicit default for
    // every window-hosting call site this file still serves (`Launcher`,
    // `WallpaperSwitcher`, the three OSDs, `NotificationPopups`) -- none of
    // those loads an `Item` with a `z` of its own, so this is a no-op for
    // them, same as before this existed.
    z: root.item?.z ?? 0

    // Where the popup's open state actually lives. Pushed into the loaded
    // popup as well as gating its lifetime, so the two can never disagree: a
    // popup still drawing itself as open while its loader counts down would
    // sit there and then blink out, which is the whole defect this file
    // exists to fix.
    property bool open: false

    // The longest exit in the shell -- the toast stack's 220ms slide. BarPopup's
    // 170ms grow-back into the pill and the power menu's 150ms dissolve both
    // finish well inside it, so one number covers every surface and they are all
    // seen to take the same time to leave.
    property int holdDuration: Motion.slow

    // Written to rather than bound. `active: root.open || hold.running` reads
    // better and is a race: that binding and the handler below both run off the
    // same change signal, in an order QML does not promise, and a binding that
    // got there first would destroy the popup before the hold had started --
    // then build a second one, mid-animation, when it did.
    active: false

    onOpenChanged: {
        if (root.open) {
            // Reopening during the hold is deliberately not a new popup. The
            // card is still there and still shrinking; handing it straight back
            // lets it grow out again from wherever it had got to instead of
            // starting over from nothing. This also absorbs the momentary false
            // of a condition like `Media.available` while a player reloads,
            // which used to tear the popup down and replay the whole entrance.
            root.hold.stop();
            root.active = true;
        } else {
            root.hold.restart();
        }
    }

    // A popup that was open when the shell reloaded comes back with `open`
    // already true at creation, and a property that starts life at its bound
    // value never emits the change the handler above is listening for.
    Component.onCompleted: if (root.open) root.active = true

    property Timer hold: Timer {
        interval: root.holdDuration
        onTriggered: root.active = false
    }

    // The popup is created before this can reach it, which is why `open`
    // defaults to true on BarPopup itself: this only ever has the closing
    // half to say. That ordering is worth keeping -- were the push to fail, a
    // popup would close the way it did before this file existed rather than
    // never open at all.
    property Binding openBinding: Binding {
        target: root.item
        property: "open"
        value: root.open
        when: root.item !== null
    }
}
