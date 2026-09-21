import Quickshell
import QtQuick

// A LazyLoader that lets the popup it holds finish leaving before it takes the
// window away.
//
// The delay deliberately does not live in BarPopup, tempting as that is -- the
// card is the one thing that knows how long its own animation runs for. But a
// window cannot outlive a decision its loader has already made: by the time the
// card could react to being closed, `active` has gone false and it no longer
// exists. The loader is the only object in the chain that is alive both while
// the popup is up and after it has been told to shut, so the hold belongs here,
// and the duration is written down here with it.
//
// It also makes the two shapes of open state look the same from Bar.qml. Some
// popups are held open by a Pill, because which bar you clicked is the whole
// question and a second monitor's pill has its own answer; others by a service,
// because Escape, a keybind and the pill must all shut one panel. Either way it
// is one bool, handed to `open` below, and this file does not care which.
LazyLoader {
    id: root

    // Where the popup's open state actually lives. Pushed into the loaded window
    // as well as gating its lifetime, so the two can never disagree: a popup
    // still drawing itself as open while its loader counts down would sit there
    // and then blink out, which is the whole defect this file exists to fix.
    property bool open: false

    // The longest exit in the shell -- the toast stack's 220ms slide. BarPopup's
    // 170ms grow-back into the pill and the power menu's 150ms dissolve both
    // finish well inside it, so one number covers every surface and they are all
    // seen to take the same time to leave.
    property int holdDuration: 220

    // Written to rather than bound. `active: root.open || hold.running` reads
    // better and is a race: that binding and the handler below both run off the
    // same change signal, in an order QML does not promise, and a binding that
    // got there first would destroy the window before the hold had started --
    // then build a second one, mid-animation, when it did.
    active: false

    onOpenChanged: {
        if (root.open) {
            // Reopening during the hold is deliberately not a new window. The
            // card is still there and still shrinking; handing it straight back
            // lets it grow out again from wherever it had got to instead of
            // starting over from nothing. This also absorbs the momentary false
            // of a condition like `Media.available` while a player reloads,
            // which used to tear the window down and replay the whole entrance.
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

    // The window is created before this can reach it, which is why `open`
    // defaults to true on the popups themselves: this only ever has the closing
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
