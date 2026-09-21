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
        spacing: 10

        Repeater {
            model: root.shown

            NotificationCard {
                id: toast

                required property var modelData

                // Whether this card is already on screen. Its initial value is
                // what does the work: a Behavior does not run while a property
                // is being given its starting value, so a card rebuilt for a
                // toast that has already arrived simply starts at rest, while a
                // genuinely new one starts off the edge and is moved in below.
                property bool entered: root.arrived.includes(toast.modelData.id)

                width: column.width
                notification: modelData
                popup: true

                // Off the right edge until the card has arrived, and back off it
                // when the stack is retired: the same travel both ways, so a
                // toast leaves the way it came instead of being cut.
                x: (toast.entered && root.open) ? 0 : width

                Component.onCompleted: {
                    if (toast.entered) return;
                    root.arrived.push(toast.modelData.id);
                    toast.entered = true;
                }

                Behavior on x {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                // Lifetime is Notifications.popupTimer's job now, so the stack
                // clears in one go instead of dribbling away card by card.
                // The card owns the click; only retiring the toast is ours.
                onActivated: Notifications.hidePopup(modelData)
            }
        }
    }
}
