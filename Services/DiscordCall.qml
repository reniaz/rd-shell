pragma Singleton
import Quickshell
import Quickshell.Io

// Idea 38 -- an incoming Vesktop call rendered as a rich banner instead of a
// generic toast. What this file does NOT do, and why, matters more than what
// it does:
//
// Vesktop ships arRPC (Discord's local RPC bridge) *disabled* by default
// (`~/.config/vesktop/settings.json`: "arRPC": false) and no `discord-ipc-*`
// socket exists in $XDG_RUNTIME_DIR on this machine even when it is on --
// and that bridge only ever lets a local app SET_ACTIVITY (rich presence)
// on Discord's own socket, never read call state or caller metadata back.
// Vesktop also owns no MPRIS or StatusNotifierItem name of its own on this
// bus. There is, in short, no IPC/RPC surface to watch here -- the plan's
// step 1 surface does not exist on a stock Vesktop install.
//
// What does exist: Discord's web client fires a plain HTML5 Notification()
// on an incoming call while unfocused, and Electron forwards that straight
// to org.freedesktop.Notifications.Notify -- the exact bus every other
// toast in this shell already arrives on (Services/Notifications.qml).
// That is what this file watches instead: `consider()` is called from
// Notifications.qml's own onNotification, before DND is even consulted (a
// call ringing is not the chatter DND is aimed at) and before a matching
// arrival is ever pushed onto the popup stack, taking it over as a call
// banner rather than letting it become a second, plain toast for the same
// event.
//
// A web Notification carries no `actions` array -- Chromium's Linux
// notification bridge does not expose one -- so there is no notification-
// level accept/decline verb. What accept()/decline() use instead is
// Discord's own documented keyboard shortcuts (support.discord.com's
// Hotkeys/Shortcuts guide): Ctrl+Enter answers an incoming call, Escape
// declines one. Both are normally scoped to Discord's *focused* window;
// Hyprland's `sendshortcut` dispatcher is documented to deliver a key to a
// named window's surface directly -- swapping keyboard focus only for that
// one keypress and handing it straight back, never raising or activating
// the target -- which is what lets accept()/decline() below act without
// yanking focus away from whatever the user is doing. Ctrl+Enter only ever
// answers with audio: Discord's own docs describe it as "Answer incoming
// call" with no mention of the camera, and the camera is never enabled on
// answer either way -- turning it on stays a separate, explicit action the
// user takes inside the call afterwards.
//
// That no-focus delivery claim caused one real incident while this was
// being built: a `sendshortcut` test aimed at a disposable ghostty window
// instead hit the user's own real ghostty terminal and toggled it
// fullscreen (the throwaway shared ghostty's class with the user's real
// window, and had likely already exited from under a concurrent test).
// accept()/decline() below never select by class for exactly that reason
// -- always one `address:0x...` resolved fresh from `hyprctl -j clients`
// right before the send, sent nowhere if that resolution is not a single
// vesktop match. A later, careful re-test with two disposable non-ghostty
// probe windows (one focused, one hidden, both address-resolved fresh)
// confirmed the delivery mechanism itself is sound: the hidden probe
// received exactly the bytes sent, the focused one received none, and
// focus/workspace never moved (see `_sendAccept`'s comment for how). What
// no test rig can confirm is that Discord/Electron answers or declines a
// call on receiving these keys -- that is only ever confirmable by
// watching a real incoming call actually stop ringing and open.
//
// "Already in a call" (idea 38's rule 5) has no real signal behind it
// either, and this file used to guess at one from PipeWire: first "any
// vesktop stream", then "a vesktop capture stream that predates this
// notification". Both were wrong, confirmed against a real incoming call
// that this shell then failed to show a banner for at all -- Vesktop keeps
// its `Stream/Output/Audio Playback` and `Stream/Input/Audio RecordStream`
// nodes open permanently, call or no call, VC or no VC, so PipeWire's own
// node list carries zero information about whether a call is under way.
// There is no PipeWire check here any more. What idea 38's rule 5 actually
// reduces to, without a real "in a call" signal to read, is narrower and
// fully answerable from the notification stream alone: never show a
// banner again for a call this session already acted on. `_answered`
// (accept) and the ordinary close/replace/decline paths below cover that;
// nothing here claims to detect a call joined some other way (Vesktop's
// own UI, a second device, ...), which is the one case idea 38's rule 5
// still cannot see.
Singleton {
    id: root

    // The one call banner in play, or null while nothing is ringing:
    // { notification, name, kind ("voice"|"video"), avatar }. Never more
    // than one -- a second incoming-call arrival while this is set just
    // replaces it, same as Discord itself only ever rings one call at a time.
    property var call: null
    readonly property bool visible: root.call !== null

    // The notification object the `closed` listener below is already
    // attached to, so a replaced-in-place notification that still matches
    // (Discord updates the same object rather than sending a new one) never
    // grows a second listener stacked on top of the first.
    property var _trackedNotification: null

    // Set by accept() to the notification it just acted on -- consider()
    // refuses to ever show a banner for that same object again, even if
    // Vesktop leaves it tracked and it somehow gets re-offered (a replace
    // that still reads as a call, e.g.). This is the whole of "don't show
    // while already on this call" now that no external signal exists to
    // confirm it: rely on the one thing this file does know for certain,
    // which is that the user already pressed accept on it.
    property var _answered: null

    // Matched the same way Services/Notifications.qml already reads every
    // arrival (appName, summary, body) -- nothing here needs a wider hook.
    // Case-insensitive appName match covers both "Vesktop" and a renamed
    // desktop-entry fallback ("discord").
    readonly property var _appRe: /vesktop|discord/i

    // Anchored to the start of the field, not the whole field -- a real
    // Vesktop call notification's exact text is still unconfirmed. A
    // `^...$` full-field anchor missed an actual incoming call outright
    // once already, so this stays deliberately tolerant: "incoming call"
    // at the very start of summary or body, an optional "voice"/"video" in
    // between, and anything after (a trailing `\b` so "incoming callback"
    // or "incoming calling" cannot false-match "call" as a prefix -- every
    // real call phrase still ends the word right there, so this costs
    // nothing legitimate). The exact text of a live call has not been
    // captured yet, hence the tolerance. Still dropped the
    // original's un-anchored "... is calling" alternative -- that one
    // matched ordinary chat too (e.g. "she is calling in sick"), which is
    // exactly the chat/call scoping idea 38 asks this file to hold.
    readonly property var _callRe: /^incoming\s+(?:(voice|video)\s+)?call\b/i

    // Returns "voice"/"video" (defaulting to "voice" when the notification
    // just says "Incoming call" with no kind word) if `text` (trimmed)
    // starts with the call phrase, null otherwise -- checked per-field
    // rather than against the two fields concatenated, so a call phrase can
    // never come from a combination that only reads that way once joined.
    function _matchCall(text) {
        const m = root._callRe.exec((text ?? "").trim());
        return m ? (m[1] ? m[1].toLowerCase() : "voice") : null;
    }

    function _looksLikeCall(n) {
        if (!root._appRe.test(n?.appName ?? "")) return false;
        return root._matchCall(n?.summary) !== null || root._matchCall(n?.body) !== null;
    }

    // Discord's own notification carries no separate "caller name" field --
    // just summary/body, one of which is the call phrase above and the
    // other the caller's name. Whichever field matched the phrase, the
    // other is the name; fall back to the app name rather than show a blank
    // banner if that side is somehow empty too.
    function _callInfo(n) {
        const s = n?.summary ?? "", b = n?.body ?? "";
        const sKind = root._matchCall(s), bKind = root._matchCall(b);
        const kind = sKind ?? bKind;
        const name = sKind ? b : s;
        return { kind: kind ?? "voice", name: name || (n?.appName ?? "Discord") };
    }

    // Called from Services/Notifications.qml before DND is consulted and
    // before a matching arrival is handed to the toast stack. Returns true
    // once this notification has been taken over as a call banner -- the
    // caller must then skip its own popup push for it, so the two never
    // both show. Returns false for anything not call-shaped, or for one
    // already accepted this session: both cases fall straight through to
    // the normal toast path with no special handling needed here, which is
    // the whole of "degrade gracefully".
    function consider(n) {
        if (!root._looksLikeCall(n)) {
            // Discord can replace a tracked notification's content in place
            // (same object, new summary/body) without ever closing it -- if
            // that happens to the one this banner is showing and the new
            // content no longer reads as a call, the banner has nothing
            // left to show for and would otherwise go stale next to
            // whatever toast just took its place.
            if (root.call?.notification === n) root.dismiss();
            return false;
        }
        if (n === root._answered) return false;

        const info = root._callInfo(n);
        root.call = { notification: n, name: info.name, kind: info.kind, avatar: n?.image ?? "" };

        // Discord withdrawing the notification (call ended, answered on
        // another device, timed out) closes the underlying object; the
        // banner has nothing left to show for once that happens. Guarded so
        // a still-matching in-place replacement never stacks a second
        // listener on the same notification.
        if (root._trackedNotification !== n) {
            root._trackedNotification = n;
            n.closed.connect(() => { if (root.call?.notification === n) root.dismiss(); });
        }
        return true;
    }

    // ---- accept/decline: the real key, not just a window raise ----
    //
    // Both resolve the one Vesktop window Hyprland currently knows about
    // fresh, every press, from `hyprctl -j clients` -- never cached, and
    // never matched by class alone (a class match would hit every Vesktop
    // window if more than one were ever open, and the wrong one is worse
    // than none). Zero matches or more than one and nothing is sent at all.
    // This also covers the window having closed between the banner showing
    // and the button press: a stale address just would not be in this
    // query's own fresh output.
    //
    // A live test of `hl.dsp.send_shortcut({ mods, key, window =
    // "address:0x.." })`, aimed at a disposable ghostty window while an
    // earlier version of this file was being built, once delivered a key
    // to the WRONG window -- the user's own real ghostty terminal, not the
    // throwaway one -- and toggled it fullscreen. That test used `ghostty`
    // (a class shared with the user's own terminal) as the throwaway
    // target and re-focused nothing in between concurrent agents opening
    // and closing windows of that same class, so the address it sent to
    // may or may not still have pointed at a live window by the time the
    // key landed -- never conclusively pinned down, and not repeated that
    // way again.
    //
    // Re-tested properly afterwards with two disposable, NON-ghostty
    // (`kitty`, unique `--class`) probe windows instead: one left focused
    // and visible, one left hidden and unfocused -- both re-resolved by
    // address immediately beforehand, both checked with `stty raw -echo`
    // so every byte lands without the kernel's own line buffering hiding
    // or reordering it. `send_shortcut` targeted at the hidden probe's
    // address delivered exactly the raw bytes sent (0x0D for Ctrl+Return,
    // 0x1B for Escape) to that probe and zero bytes to the focused one, and
    // `hyprctl activewindow`/`activeworkspace` read identical before and
    // after every send on both monitors -- repeated with the hidden probe
    // on a scratch special-workspace and again on a plain numbered
    // workspace neither monitor had in view (mirroring Vesktop's own usual
    // workspace 7), both clean. That confirms `sendshortcut` itself does
    // not need, take, or leak focus at the compositor level; it does not,
    // and cannot, confirm that Discord/Electron's own key handling behaves
    // identically to a raw terminal reading its pty -- see `_sendAccept`
    // below for what still rests on that.
    property var _pendingAction: null
    property var _pendingNotification: null

    Process {
        id: _vesktopQuery
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: root._onVesktopResolved(this.text)
        }
    }

    function _resolveVesktopThen(action, notification) {
        if (_vesktopQuery.running) return; // one lookup in flight is enough for two buttons
        root._pendingAction = action;
        root._pendingNotification = notification;
        _vesktopQuery.running = true;
    }

    function _onVesktopResolved(text) {
        const action = root._pendingAction;
        const notification = root._pendingNotification;
        root._pendingAction = null;
        root._pendingNotification = null;

        let clients;
        try { clients = JSON.parse(text || "[]"); } catch (e) { clients = []; }
        const matches = clients.filter(c => (c?.class ?? "").toLowerCase() === "vesktop");
        // None, or ambiguous -- send nothing, and the banner has nothing
        // honest left to offer (accept can't join, decline can't decline)
        // once the one window it would act on can't be resolved uniquely.
        if (matches.length !== 1 || !/^0x[0-9a-f]+$/i.test(matches[0]?.address ?? "")) {
            if (root.call?.notification === notification) root.dismiss();
            return;
        }
        const address = matches[0].address;

        if (action === "accept") root._sendAccept(address, notification);
        else if (action === "decline") root._sendDecline(address);
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
    // output, never from notification text.
    function _sendAccept(address, notification) {
        if (root.call?.notification !== notification) return; // banner moved on while this was resolving
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.dispatch(hl.dsp.send_shortcut({ mods = 'CTRL', key = 'Return', window = 'address:" + address + "' }))"]);
        root._answered = notification;
        root.dismiss();
    }

    // Escape -- Discord's documented "Decline incoming call", sent the same
    // way as accept()'s Ctrl+Return (see that comment for what the probe
    // test does and does not prove about delivery). decline() below
    // dismisses the banner regardless of whether this send actually
    // reached anything: even with no Vesktop window resolved, "make the
    // banner go away" is the one part of decline this file can always
    // deliver honestly.
    function _sendDecline(address) {
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.dispatch(hl.dsp.send_shortcut({ mods = '', key = 'Escape', window = 'address:" + address + "' }))"]);
    }

    // Only while a live, not-closed call banner is actually showing --
    // `root.visible` is false once `dismiss()` has run, whether from a
    // prior accept/decline or from Discord itself closing the notification.
    function accept() {
        if (!root.visible) return;
        root._resolveVesktopThen("accept", root.call.notification);
    }

    function decline() {
        if (!root.visible) return;
        root._resolveVesktopThen("decline", root.call.notification);
        root.dismiss();
    }

    function dismiss() {
        root.call = null;
    }
}
