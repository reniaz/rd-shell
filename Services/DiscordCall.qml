pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Idea 38 -- an incoming Vesktop call rendered as a rich banner instead of a
// generic toast.
//
// The previous version of this file watched org.freedesktop.Notifications
// for a text pattern ("Incoming call" et al), on the theory that Discord's
// web client fires a plain Notification() on a ring and Electron forwards it
// to the same bus every other toast arrives on. A real incoming call proved
// that wrong: Vesktop sends no desktop notification for a ring at all, so
// that path never fired and never could. It also had a real cost sitting in
// Services/Notifications.qml's onNotification -- any DM whose text happened
// to start with "incoming call" (someone literally typing that) would have
// been silently swallowed and shown as a fake call banner instead of the
// message it was. That hook is gone; see Notifications.qml for the removal.
//
// What actually exists: the installed Vencord has a plugin, "XSOverlay",
// whose CALL_UPDATE handler -- when call.ringing includes the current user
// and its own callNotifications setting is on -- opens
// ws://127.0.0.1:42070/?client=Vencord (from the discord.com page itself,
// so Origin https://discord.com) and sends one text frame carrying a
// {"title":"<channel> is calling you...","content":"Incoming call",
// "useBase64Icon":false, ...} envelope. That is a real signal with no
// notification-bus detour needed. No QtWebSockets QML module is installed
// here and no installs are allowed for this fix, so the other end of that
// socket is scripts/vencord-call-bridge.py -- a small python3 stdlib
// WebSocket server this file owns as a Quickshell Process. It parses the
// envelope itself and only ever prints one line per detected ring to
// stdout: {"event":"ring","name":"<channel name or empty>"}. It never knows
// or reports voice vs. video (Vencord's own event carries nothing that
// says), which is why `call.kind` below is always null -- see
// DiscordCallBanner.qml for how that shows.
//
// Nothing in this file consults Notifications.dnd, on purpose: a call
// ringing is not the chatter DND exists to hold back, and the user asked
// for this banner to survive DND same as before.
//
// ---- accept/decline: the real key, not just a window raise ----
//
// Unchanged from the notification-based version. Both resolve the one
// Vesktop window Hyprland currently knows about fresh, every press, from
// `hyprctl -j clients` -- never cached, and never matched by class alone (a
// class match would hit every Vesktop window if more than one were ever
// open, and the wrong one is worse than none). Zero matches or more than
// one and nothing is sent at all. This also covers the window having closed
// between the banner showing and the button press: a stale address just
// would not be in this query's own fresh output.
//
// A live test of `hl.dsp.send_shortcut({ mods, key, window =
// "address:0x.." })`, aimed at a disposable ghostty window while an earlier
// version of this file was being built, once delivered a key to the WRONG
// window -- the user's own real ghostty terminal, not the throwaway one --
// and toggled it fullscreen. That test used `ghostty` (a class shared with
// the user's own terminal) as the throwaway target and re-focused nothing
// in between concurrent agents opening and closing windows of that same
// class, so the address it sent to may or may not still have pointed at a
// live window by the time the key landed -- never conclusively pinned down,
// and not repeated that way again.
//
// Re-tested properly afterwards with two disposable, NON-ghostty (`kitty`,
// unique `--class`) probe windows instead: one left focused and visible,
// one left hidden and unfocused -- both re-resolved by address immediately
// beforehand, both checked with `stty raw -echo` so every byte lands
// without the kernel's own line buffering hiding or reordering it.
// `send_shortcut` targeted at the hidden probe's address delivered exactly
// the raw bytes sent (0x0D for Ctrl+Return, 0x1B for Escape) to that probe
// and zero bytes to the focused one, and `hyprctl activewindow`/
// `activeworkspace` read identical before and after every send on both
// monitors. That confirms `sendshortcut` itself does not need, take, or
// leak focus at the compositor level; it does not, and cannot, confirm that
// Discord/Electron's own key handling behaves identically to a raw
// terminal reading its pty -- see `_sendAccept` below for what still rests
// on that.
Singleton {
    id: root

    // The one call banner in play, or null while nothing is ringing:
    // { name, kind }. kind is always null -- this source (Vencord's
    // CALL_UPDATE via the bridge) never knows voice vs. video, unlike the
    // old notification text guess. Never more than one call shown at once --
    // a second incoming ring while this is set just replaces it, same as
    // Discord itself only ever rings one call at a time.
    property var call: null
    readonly property bool visible: root.call !== null

    // Identifies the ring currently "in play" (showing, or already
    // answered/declined and cooling down) -- the channel name the bridge
    // last reported, or "" for a nameless 1:1 DM. Vencord's CALL_UPDATE
    // fires several times over one ring with no "stopped ringing" event
    // ever sent, so there is no hard boundary between "still the same call"
    // and "a new one" to read off the wire -- this file draws that
    // boundary itself: a ring event for the SAME name while `_ringTimer` is
    // still running is treated as the same ring (never re-shown if already
    // handled, still refreshed if not); a different name, or this same name
    // after the timer has lapsed, starts a fresh ring. That means two
    // different silent (empty-name) DM callers back to back within the
    // window would misread as one ring -- an accepted limitation of having
    // only a channel name to go on, not a bug in the timer.
    property string _activeName: ""
    property bool _haveActive: false
    property bool _handled: false

    // No official cadence for CALL_UPDATE is documented and none was
    // captured live before this was built, so this is a judgment call, not
    // a measured number: comfortably longer than any gap between repeats of
    // one real ring should be, comfortably shorter than "the user forgot
    // and this is a stale banner nobody will ever act on". Also stands in
    // for the notification-based version's `closed` signal as the one way
    // this file now learns "the call is presumably over" (answered on
    // another device, hung up, timed out) -- there is no such signal from
    // the bridge, so silence itself is that signal.
    readonly property int ringTimeoutMs: 30000

    Timer {
        id: ringTimer
        interval: root.ringTimeoutMs
        onTriggered: {
            root.call = null;
            root._haveActive = false;
            root._handled = false;
        }
    }

    // Bridge process -- scripts/vencord-call-bridge.py, launched the same
    // way Services/SysMon.qml launches its own long-running python3
    // sampler, including the same crash-loop backoff (doubled each time the
    // process dies within 5s of starting, reset once one runs longer than
    // that). "Port busy" reads here as just another fast exit: SO_REUSEADDR
    // means a hot-reloaded bridge rebinds instantly, so a fast exit here
    // means something else already owns 127.0.0.1:42070 -- worth one
    // warning, not a log line every retry.
    property int _backoff: 1000
    property real _startedAt: 0
    property bool _loggedStuck: false

    Timer {
        id: restartTimer
        onTriggered: bridge.running = true
    }

    Process {
        id: bridge
        running: true
        command: ["python3", Quickshell.shellPath("scripts/vencord-call-bridge.py")]

        onRunningChanged: if (bridge.running) root._startedAt = Date.now()

        onExited: (exitCode, exitStatus) => {
            if (Date.now() - root._startedAt > 5000) {
                root._backoff = 1000;
                root._loggedStuck = false;
            } else {
                root._backoff = Math.min(root._backoff * 2, 30000);
                if (root._backoff >= 30000 && !root._loggedStuck) {
                    console.warn("DiscordCall: vencord-call-bridge.py keeps exiting right after start (is 127.0.0.1:42070 already in use?) -- retrying quietly every 30s");
                    root._loggedStuck = true;
                }
            }
            restartTimer.interval = root._backoff;
            restartTimer.start();
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._onBridgeLine(data)
        }
    }

    // The bridge never prints anything but {"event":"ring","name":...} --
    // no message content, ever (see its own header comment) -- but this
    // still parses defensively rather than trust a line blindly: a stray
    // partial line across a restart should never throw past this function.
    function _onBridgeLine(line) {
        let msg;
        try { msg = JSON.parse(line); } catch (e) { return; }
        if (msg?.event !== "ring") return;
        root._onRing(typeof msg.name === "string" ? msg.name : "");
    }

    function _onRing(name) {
        if (root._haveActive && root._activeName === name && ringTimer.running) {
            // Same ring, still sending CALL_UPDATEs: refresh the window so
            // silence-based expiry keeps counting from the most recent
            // update, but never flip a banner the user already acted on
            // back on.
            ringTimer.restart();
            if (!root._handled) root.call = { name: name || "Discord", kind: null };
            return;
        }

        // Different name, or nothing currently active/it already expired --
        // always a fresh ring.
        root._activeName = name;
        root._haveActive = true;
        root._handled = false;
        root.call = { name: name || "Discord", kind: null };
        ringTimer.restart();
    }

    property var _pendingAction: null
    property string _pendingRingName: ""

    Process {
        id: _vesktopQuery
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: root._onVesktopResolved(this.text)
        }
    }

    function _resolveVesktopThen(action, ringName) {
        if (_vesktopQuery.running) return; // one lookup in flight is enough for two buttons
        root._pendingAction = action;
        root._pendingRingName = ringName;
        _vesktopQuery.running = true;
    }

    function _onVesktopResolved(text) {
        const action = root._pendingAction;
        const ringName = root._pendingRingName;
        root._pendingAction = null;
        root._pendingRingName = "";

        let clients;
        try { clients = JSON.parse(text || "[]"); } catch (e) { clients = []; }
        const matches = clients.filter(c => (c?.class ?? "").toLowerCase() === "vesktop");
        // None, or ambiguous -- send nothing, and the banner has nothing
        // honest left to offer (accept can't join, decline can't decline)
        // once the one window it would act on can't be resolved uniquely.
        if (matches.length !== 1 || !/^0x[0-9a-f]+$/i.test(matches[0]?.address ?? "")) {
            if (root._activeName === ringName) root.dismiss();
            return;
        }
        const address = matches[0].address;

        if (action === "accept") root._sendAccept(address, ringName);
        else if (action === "decline") root._sendDecline(address, ringName);
    }

    // Ctrl+Enter -- Discord's documented "Answer incoming call", audio
    // only, camera never enabled on answer (see the header comment). Sent
    // straight to the resolved Vesktop window via `sendshortcut`, with no
    // focus/raise call around it. The probe test above proves that
    // delivery itself reaches an unfocused/hidden window cleanly at the
    // compositor level; it cannot prove Discord/Electron actually answers
    // the call on receiving it -- only a real incoming call does that, and
    // only visibly (the ring stops, the call view opens). If Electron
    // turns out to need real activation to accept a synthetic key, accept()
    // will visibly do nothing rather than silently misbehave, since nothing
    // here falls back to raising the window instead. Argv is fixed except
    // for the address itself, which comes from `hyprctl`'s own trusted
    // output, never from anything Vencord sent.
    function _sendAccept(address, ringName) {
        if (root._activeName !== ringName) return; // banner moved on while this was resolving
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.dispatch(hl.dsp.send_shortcut({ mods = 'CTRL', key = 'Return', window = 'address:" + address + "' }))"]);
        root._handled = true;
        root.dismiss();
    }

    // Escape -- Discord's documented "Decline incoming call", sent the same
    // way as accept()'s Ctrl+Return (see that comment for what the probe
    // test does and does not prove about delivery). decline() below
    // dismisses the banner regardless of whether this send actually
    // reached anything: even with no Vesktop window resolved, "make the
    // banner go away" is the one part of decline this file can always
    // deliver honestly.
    function _sendDecline(address, ringName) {
        if (root._activeName !== ringName) return; // banner moved on while this was resolving
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.dispatch(hl.dsp.send_shortcut({ mods = '', key = 'Escape', window = 'address:" + address + "' }))"]);
    }

    // Only while a live, not-dismissed call banner is actually showing --
    // `root.visible` is false once `dismiss()` has run, whether from a
    // prior accept/decline or from the ring timing out.
    function accept() {
        if (!root.visible) return;
        root._handled = true;
        root._resolveVesktopThen("accept", root._activeName);
    }

    function decline() {
        if (!root.visible) return;
        root._handled = true;
        root._resolveVesktopThen("decline", root._activeName);
        root.dismiss();
    }

    function dismiss() {
        root.call = null;
    }
}
