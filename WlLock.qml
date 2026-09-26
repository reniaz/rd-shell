pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// Native lock screen, driven over IPC (target "lock": lock(),
// test(seconds), status()). Super+L runs scripts/lock.sh, which calls
// lock() and falls back to hyprlock if this lock never takes or the shell
// goes away while locked; hypridle's own lock path is unchanged. This file owns the
// WlSessionLock itself, the one PamContext every screen's LockSurface types
// into, and the IPC handler; LockSurface.qml (same directory) is the
// per-screen visual -- WlSessionLock instantiates one WlSessionLockSurface
// per Quickshell.screens entry from the Component below on its own (see its
// onScreensChanged), so this file never wraps it in a Variants block the way
// Wallpaper/BarWindow/EdgeBar do in shell.qml.
//
// Reload safety (this is the load-bearing part of this file): Quickshell's
// hot reload destroys and recreates this whole Scope's QML tree on every
// save -- to ANY file this shell loads, not just this one -- and per
// quickshell's own src/wayland/session_lock.cpp, WlSessionLock::onReload
// hands the *live* Wayland lock object over to the newly-created instance
// and then immediately calls realizeLockTarget() off that new instance's
// own `locked` property. A `property bool testActive: false` or an
// imperative `sessionLock.locked = true` -- what this file used to carry --
// is gone the instant the tree is rebuilt and comes back at its QML
// default, so an unrelated agent saving an unrelated file while a REAL lock
// was held would have silently unlocked the session. `lockState` below
// exists only to close that hole: it is a `PersistentProperties`, whose
// whole reason to exist is surviving exactly this kind of reload as long as
// its `reloadableId` matches between the old generation and the new one,
// and `sessionLock.locked` is now a pure binding off it rather than
// something this file ever assigns directly. Declaration order matters and
// is not cosmetic: `lockState` is declared BEFORE `sessionLock`, in the same
// parent, because Quickshell reattaches Reloadable objects (both
// PersistentProperties and WlSessionLock are one) in the order they were
// discovered in the tree -- lockState's own onReload has to repopulate
// `realLock`/`testDeadline` before WlSessionLock's onReload reads `locked`
// through the binding below, or the new instance would call
// realizeLockTarget() against the same stale default this bug used to hit.
// This ordering guarantee comes from reading quickshell's own reload
// implementation, not from any documented public contract of
// PersistentProperties -- if that internal detail ever changes, this file's
// only remaining defense is "don't save qs-bar files while a real lock is
// held", which is no longer this file's to enforce. Everything else about
// the safety invariant is unchanged: a REAL lock (`lockState.realLock`) can
// only ever be cleared by a successful PamContext.completed with
// PamResult.Success below; the IPC handler exposes no unlock function at
// all; and test()'s self-release only ever touches `lockState.testDeadline`,
// never `realLock`. The WlSessionLock's own id is deliberately not called
// "lock": the IPC target below declares a function literally named
// `lock()`, and giving the two the same identifier would make every
// reference inside that function ambiguous between "the id" and "the
// function on this object" -- see QML's own name-resolution order (own
// members before ids). Every cross-reference in this file is written out
// fully qualified for the same reason, even where a bare id would probably
// also have worked.
Scope {
    id: root

    // Reload-persistent lock state -- see the header comment above for why
    // this exists and why it has to be declared before WlSessionLock.
    PersistentProperties {
        id: lockState

        reloadableId: "wllock-state"

        // True only between lock() succeeding and a PAM success clearing
        // it. A reload must never be able to flip this on its own -- only
        // PamContext.onCompleted (Success) and nothing else in this file
        // is allowed to set it back to false.
        property bool realLock: false

        // 0 while no test lock is running; otherwise the epoch-ms deadline
        // test() armed. An absolute deadline is what makes this
        // reload-safe: a plain Timer's own countdown does not survive being
        // recreated, but "is Date.now() past this number" needs nothing
        // saved except the number itself.
        property real testDeadline: 0
    }

    WlSessionLock {
        id: sessionLock

        // The only place `locked` is ever driven from. Both persisted
        // fields it depends on default to their "unlocked" value on a
        // genuinely fresh start, so a first-ever load is unaffected.
        locked: lockState.realLock || lockState.testDeadline > 0

        // Covers every path back to unlocked, not just PAM success: a real
        // lock released some other way (recovery from a TTY, say) must not
        // leave stale test/PAM state sitting around.
        onLockedChanged: if (!sessionLock.locked) {
            lockState.realLock = false;
            lockState.testDeadline = 0;
            lockPam.reset();
        }

        LockSurface {
            lock: sessionLock
            pam: lockPam
        }
    }

    // One PamContext for every screen's LockSurface: only one physical
    // keyboard exists, and whichever surface the compositor actually hands
    // key events to drives this same instance, so every screen agrees on
    // the buffer length and the fail flash.
    QtObject {
        id: lockPam

        property string buffer: ""
        readonly property bool busy: pamCtx.active
        property bool failed: false

        signal failFlash

        function handleKey(event) {
            if (lockPam.busy) return;

            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                if (lockPam.buffer.length > 0) lockPam.pamCtx.start();
            } else if (event.key === Qt.Key_Backspace) {
                lockPam.buffer = (event.modifiers & Qt.ControlModifier) ? "" : lockPam.buffer.slice(0, -1);
            } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
                lockPam.buffer += event.text;
            }
            lockPam.failed = false;
        }

        function reset() {
            lockPam.pamCtx.abort();
            lockPam.buffer = "";
            lockPam.failed = false;
        }

        property PamContext pamCtx: PamContext {
            // hyprlock's own /etc/pam.d service file ("auth include login")
            // -- read straight off disk, no sudo, no bundled copy.
            config: "hyprlock"

            onResponseRequiredChanged: {
                if (!responseRequired) return;
                respond(lockPam.buffer);
                lockPam.buffer = "";
            }

            onCompleted: res => {
                if (res === PamResult.Success) {
                    lockPam.buffer = "";
                    lockPam.failed = false;
                    // The only place in this file that clears a REAL lock.
                    lockState.realLock = false;
                    return;
                }

                lockPam.buffer = "";
                lockPam.failed = true;
                lockPam.failFlash();
            }
        }
    }

    // test()'s own self-release, as a short poll against the persisted
    // deadline rather than a single-shot interval: `running` re-evaluates
    // true the instant this Timer is recreated post-reload (lockState has
    // already been repopulated by then -- see the header comment), and
    // `triggeredOnStart` means it checks immediately rather than waiting out
    // a fresh interval, so a deadline that already passed during the reload
    // itself is caught on the very next tick instead of needing "remaining
    // time" to be reconstructed by hand.
    Timer {
        interval: 200
        repeat: true
        triggeredOnStart: true
        running: lockState.testDeadline > 0
        onTriggered: {
            if (lockState.testDeadline > 0 && Date.now() >= lockState.testDeadline) {
                lockState.testDeadline = 0;
            }
        }
    }

    // qs -c rd-shell ipc call lock lock   (Super+L goes through scripts/lock.sh)
    // qs -c rd-shell ipc call lock test 8
    // qs -c rd-shell ipc call lock status
    IpcHandler {
        target: "lock"

        function lock(): void {
            lockState.testDeadline = 0;
            lockState.realLock = true;
        }

        // Self-unlocking test lock, capped at 10s regardless of what is
        // asked for. Refuses to arm on top of an already-real lock, so this
        // can never be used to sneak an IPC-triggered unlock onto a lock a
        // person actually set by calling lock() (or, later, a real keybind).
        function test(seconds: int): void {
            if (lockState.realLock) return;
            lockState.testDeadline = Date.now() + Math.max(1, Math.min(seconds, 10)) * 1000;
        }

        // "locking" until the compositor confirms the lock (secure), so
        // scripts/lock.sh can tell a lock that never took from one that did.
        function status(): string {
            if (lockState.realLock) return sessionLock.secure ? "locked" : "locking";
            if (lockState.testDeadline > 0) return "test";
            return "unlocked";
        }
    }
}
