# Lock screen

`Super+L` and the power menu's **Lock** both run `scripts/lock.sh`, which
tries the shell's own native lock (`WlLock.qml` + `LockSurface.qml`) first
and falls back to `hyprlock` whenever that lock doesn't take, or later dies.

## How the handoff works

`lock.sh` talks to the running shell over IPC (`qs ipc -c rd-shell call lock
…`):

1. Asks the shell to `lock`.
2. Polls `status` for up to 2 seconds, waiting for `locked` (the compositor
   has confirmed the surface is secure — `status` reports `locking` in
   between).
3. If it never reaches `locked`, falls straight back to `hyprlock`.
4. Once locked, keeps watching: if the shell restarts, stops answering for
   about 3 seconds, or reports anything other than `locked`/`locking`,
   `hyprlock` takes over as a watchdog fallback.

`misc.allow_session_lock_restore = true` in `hyprland.lua` is what lets
`hyprlock` pick up a session another lock client already holds — without it,
a dead lock client would leave Hyprland showing its own "lock app died"
screen with no way for `hyprlock` to take over.

## Reload safety

Quickshell's hot reload tears down and rebuilds this whole file's QML tree
on **every** save to **any** file the shell loads, not just this one.
`WlLock.qml` keeps its actual lock state in a `PersistentProperties` block
specifically so a real lock survives that — an ordinary QML property would
reset to its default the instant the tree rebuilds, which would have meant
an unrelated agent saving an unrelated file silently unlocking the session
mid-lock.

## IPC (`target: "lock"`)

| Call | Does |
|---|---|
| `lock` | Locks now. |
| `test <seconds>` | A self-releasing test lock, capped at 10s — refuses to arm on top of a real lock. |
| `status` | `locked` / `locking` / `test` / `unlocked`. |

```bash
qs -c rd-shell ipc call lock lock
qs -c rd-shell ipc call lock status
```
