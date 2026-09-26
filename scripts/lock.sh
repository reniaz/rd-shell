#!/usr/bin/env bash
# Super+L and the power menu's Lock: the shell's own lock screen (WlLock.qml),
# falling back to hyprlock whenever that lock does not take or later dies.
#
# A dead lock client leaves Hyprland showing its "lock app died" screen with
# the session still locked; misc.allow_session_lock_restore (hyprland.lua) lets
# hyprlock take that lock over, so the watchdog below can always hand off.
set -u

ipc() { timeout 2 qs -c rd-shell ipc call lock "$@" 2>/dev/null; }
shell_pid() { pgrep -xf 'qs -c rd-shell' | head -n1; }

pidof hyprlock >/dev/null && exit 0
case "$(ipc status)" in locked|locking) exit 0 ;; esac

pid=$(shell_pid)
[ -n "$pid" ] && ipc lock
for _ in $(seq 20); do
    [ "$(ipc status)" = locked ] && break
    sleep 0.1
done
[ "$(ipc status)" = locked ] || exec hyprlock

# Watch the lock until a successful unlock. A shell that exits or restarts
# (new pid) has dropped its lock state; one that stops answering for ~3 s
# has hung. Either way hyprlock takes over. Short IPC gaps are hot reloads.
misses=0
while sleep 1; do
    [ "$(shell_pid)" = "$pid" ] || exec hyprlock
    case "$(ipc status)" in
        locked|locking) misses=0 ;;
        # Only an unlock from the same shell is a real one: a restarted
        # shell answers "unlocked" while the dead lock still holds the session.
        unlocked) [ "$(shell_pid)" = "$pid" ] && exit 0; exec hyprlock ;;
        *) misses=$((misses + 1)); [ "$misses" -ge 3 ] && exec hyprlock ;;
    esac
done
