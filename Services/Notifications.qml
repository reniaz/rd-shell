pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Services.Notifications

Singleton {
    id: root

    // Owned here rather than by a window, so the panel, the popups and the IPC
    // handler all read one source of truth (same shape as Services/Power.qml).
    property bool panelOpen: false

    // This used to be paired with a `panelClosing` flag and a release timer, so
    // that the LazyLoader did not rip the window away mid-animation. Six other
    // popups needed the same thing and had none, so the grace period moved to
    // PopupLoader.qml, where every popup in the bar gets it from one place. The
    // service is back to saying only whether the panel is wanted.

    // Subset currently shown as toasts. A notification leaves this list when the
    // shared popupTimer fires but stays in `list` until actually dismissed.
    property var popups: []

    // Arrivals since the panel was last opened -- drives the bar's badge dot.
    // Counted even under DND: DND suppresses the toast, not the record, so the
    // badge is the only way a quiet arrival is ever noticed.
    property int unseen: 0
    readonly property bool hasUnseen: unseen > 0

    // Notification has no timestamp property in quickshell 0.3.1, so arrival times
    // are recorded here, keyed by id. Reset on reload -- see timeOf().
    property var times: ({})

    // Persisted across restarts; PersistentProperties would only survive reloads.
    readonly property bool dnd: dndState.adapter?.dnd ?? false

    FileView {
        id: dndState

        path: Quickshell.statePath("state.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            property bool dnd: false
        }
    }

    readonly property var list: [...server.trackedNotifications.values].reverse()
    readonly property int count: server.trackedNotifications.values.length

    // [{ app, items[] }], groups ordered by their most recent notification
    readonly property var grouped: {
        const groups = [];
        const byApp = ({});
        for (const n of list) {
            const key = n.appName !== "" ? n.appName : "Unknown";
            if (!byApp[key]) {
                byApp[key] = { app: key, items: [] };
                groups.push(byApp[key]);
            }
            byApp[key].items.push(n);
        }
        return groups;
    }

    NotificationServer {
        id: server

        keepOnReload: true
        // Hotkey scripts tag their feedback with this hint; quickshell discards
        // any hint not listed here, so without it isHotkey() never matches.
        extraHints: ["x-rd-hotkey"]
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        // Without tracked = true quickshell drops the notification the moment this
        // handler returns.
        onNotification: n => {
            n.tracked = true;                       // always recorded -> panel
            // Without this a notification replaced via replaces-id (or closed by
            // the sending app) stays in the popup stack forever.
            n.closed.connect(() => root.hidePopup(n));
            root.times[n.id] = new Date();
            // Not while the panel is open: the user is already looking at the
            // list, so counting there would leave a stale badge behind on close.
            if (!root.panelOpen) root.unseen++;
            // DiscordCall.consider() takes over the one arrival that looks
            // like an incoming Vesktop call (idea 38) before DND is even
            // consulted -- a call ringing is not the chatter DND is aimed
            // at, so it must survive DND the same as a hotkey or an allowed
            // app does below. Taking it over here, before the toast stack
            // is ever touched, is also what keeps the rich banner and this
            // plain toast from both showing for the same call. Anything
            // else -- ordinary chat, or a call arriving while already on
            // one -- it hands straight back, unchanged, to the normal
            // DND-gated toast path.
            if (DiscordCall.consider(n)) return;

            // filter first: a replaced notification arrives as the same object, so
            // a blind prepend stacks visual duplicates of one notification
            if (!root.dnd || root.bypassesDnd(n)) {
                root.popups = [n, ...root.popups.filter(p => p !== n)];
                popupTimer.restart();
            }
        }
    }

    // One timer for the whole stack rather than one per toast: a per-toast timer
    // retires each card on its own arrival time, which leaves the stack dribbling
    // away card by card. Restarting a single timer on every arrival keeps a late
    // notification readable and still clears everything in one go. Critical
    // notifications expire with the rest -- only their red border sets them apart.
    Timer {
        id: popupTimer

        interval: 2000
        onTriggered: root.popups = []
    }

    // Empty for notifications that survived a config reload, whose arrival time
    // was not carried over.
    function timeOf(n) {
        const t = root.times[n?.id];
        return t ? Qt.formatDateTime(t, "HH:mm") : "";
    }

    // Feedback for a key the user just pressed rather than an interruption, so
    // it is shown even under DND -- and the card then spells the DND state out,
    // which is the only signal the user gets that everything else is being
    // swallowed. Tagged by scripts/*.sh with -h boolean:x-rd-hotkey:true.
    function isHotkey(n) {
        return !!(n?.hints?.["x-rd-hotkey"]);
    }

    // Apps whose notifications are shown even under do-not-disturb, matched on
    // the sending app's own name. DND is turned on against the machine's
    // chatter; a message from a person and an alarm you set yourself are the two
    // things you meant to keep hearing through it. Substrings, so a client that
    // renames itself from "whatsapp" to "whatsapp-client" keeps working.
    readonly property var dndAllow: ["whatsapp", "reminder"]

    // Hotkey feedback and the apps above: shown under DND, which suppresses the
    // interruptions and not these.
    function bypassesDnd(n) {
        const app = (n?.appName ?? "").toLowerCase();
        return isHotkey(n) || dndAllow.some(allowed => app.includes(allowed));
    }

    function setDnd(v) {
        dndState.adapter.dnd = v;
        if (v) popups = [];   // clear anything already on screen
    }

    function toggleDnd() {
        setDnd(!dnd);
    }

    function openPanel() {
        unseen = 0;
        panelOpen = true;
    }

    function closePanel() {
        panelOpen = false;
    }

    function togglePanel() {
        if (panelOpen) closePanel();
        else openPanel();
    }

    function hidePopup(n) {
        root.popups = root.popups.filter(p => p !== n);
    }

    function dismiss(n) {
        hidePopup(n);
        n.dismiss();
    }

    function dismissAll() {
        root.popups = [];
        root.unseen = 0;
        // copy first: dismissing mutates the model we would be iterating
        for (const n of [...server.trackedNotifications.values]) n.dismiss();
    }
}
