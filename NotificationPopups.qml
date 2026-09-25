import Quickshell
import Quickshell.Wayland
import QtQuick
import Quickshell.Services.Notifications
import qs.Config
import qs.Services

PanelWindow {
    id: root

    // Written by the PopupLoader that owns this window, which keeps it alive
    // past the moment the last toast is retired -- see PopupLoader.qml. True by
    // default because the window exists before its loader can reach it.
    property bool open: true

    // The toasts this window is drawing, which is deliberately not the same list
    // the service holds. The stack is retired in one go by Notifications'
    // popupTimer, so by the time `open` goes false the service's list is already
    // empty -- and a Repeater handed an empty model has destroyed its cards and
    // has nothing left to slide anywhere. Keeping the last non-empty list is the
    // whole reason the exit is visible.
    property var shown: []

    // Never takes an empty list, rather than testing `open`: the emptying and
    // the close arrive on the same change, in an order QML does not promise, and
    // a guard that lost that race would clear the stack it was written to hold.
    // Nothing else ever empties it, and the loader is what clears it for good.
    function resync() {
        if (Notifications.popups.length > 0) root.shown = Notifications.popups;
    }

    // Which toasts have already played their entrance, by notification id. The
    // model is a plain array, so an arrival hands the Repeater a new one and it
    // rebuilds the whole stack -- without this, every toast you were still
    // reading would slide in again behind the new one. Nothing binds to it, so
    // pushing to it in place is deliberate: it must not itself cause a redraw.
    property var arrived: []

    Component.onCompleted: root.resync()

    Connections {
        target: Notifications

        function onPopupsChanged() { root.resync(); }
    }

    // floats clear of the screen edge -- 54 clears the 40px bar plus the bar's
    // own 14px edge rhythm
    anchors { top: true; right: true }
    margins { top: 54; right: 14 }
    implicitWidth: 400
    implicitHeight: Math.max(1, column.implicitHeight)

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-popups"
    color: "transparent"

    // The cards are clickable, so this surface takes input -- but only while
    // there is something on it to click. Emptying the region as the stack leaves
    // stops a corner of the screen eating clicks for a slide's worth of time
    // after the last toast has gone.
    mask: root.open ? null : closedMask

    Region { id: closedMask }

    Column {
        id: column

        width: parent.width
        spacing: Caelus.spaceLoose

        Repeater {
            model: root.shown

            // Not a card of its own: the shell only carries the slide below.
            // A toast used to sit in a glass frame here (Colors.popupBg, a
            // radiusIsland edge) to match BarPopup, but a toast lands over
            // whatever window happens to be focused, so that frame showed a
            // blurred slice of some random window round an opaque card -- a
            // ring that read as a rendering fault rather than as glass. The
            // NotificationCard inside is the whole toast now: solid
            // notifCardBg, its own edge and radius, legible over any backdrop.
            Item {
                id: shell

                required property var modelData

                // Whether this toast is already on screen. Its initial value is
                // what does the work: a Behavior does not run while a property
                // is being given its starting value, so a shell rebuilt for a
                // toast that has already arrived simply starts at rest, while a
                // genuinely new one starts off the edge and is moved in below.
                property bool entered: root.arrived.includes(shell.modelData.id)

                width: column.width
                implicitHeight: toast.implicitHeight

                // Off the right edge until the toast has arrived, and back off
                // it when the stack is retired: the same travel both ways, so a
                // toast leaves the way it came instead of being cut.
                x: width

                Component.onCompleted: {
                    if (shell.entered) return;
                    root.arrived.push(shell.modelData.id);
                    shell.entered = true;
                }

                // Was a ternary binding on `x` plus a Behavior; an XAnimator
                // can't share `x` with a binding without the two fighting
                // every frame, so the two states this toast actually has
                // (off-screen, arrived) moved into a State pair instead. The
                // render-thread slide is what keeps a toast moving smoothly
                // while this same Repeater is busy rebuilding for the next
                // arrival on the GUI thread.
                states: State {
                    name: "in"
                    when: shell.entered && root.open
                    PropertyChanges { target: shell; x: 0 }
                }

                transitions: Transition {
                    XAnimator { target: shell; duration: Motion.slow; easing.type: Motion.standard }
                }

                NotificationCard {
                    id: toast

                    anchors.centerIn: parent
                    width: shell.width
                    notification: shell.modelData
                    popup: true

                    // Lifetime is Notifications.popupTimer's job now, so the
                    // stack clears in one go instead of dribbling away card by
                    // card. The card owns the click; only retiring the toast is
                    // ours.
                    onActivated: Notifications.hidePopup(shell.modelData)
                }
            }
        }
    }
}
