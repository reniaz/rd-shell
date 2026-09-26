# Notifications

`rd-shell` owns the `org.freedesktop.Notifications` D-Bus name itself —
`install.sh` masks any competing daemon (`swaync`, `dunst`, `mako`) since it's
an exclusive name and a D-Bus-activated daemon just restarts itself the
moment anything sends a notification.

- **Popups** (`NotificationPopups.qml` / `NotificationCard.qml`) — grouped
  toasts as notifications arrive.
- **History centre** (`NotificationPanel.qml`) — full history, `Super+N`.
- **Bell** (`NotificationBell.qml`) — bar pill, badges unread count; swings
  and shows a red slash while DND is on, the same `MuteGlyph.qml` motion the
  mic/volume pills use for mute.
- **DND** — silences popups, but still lets through hotkey feedback (e.g.
  mic toggle) and an allow-list of apps. Reminders (from `CalendarPopup.qml`)
  still ring with sound even under DND. So does the Discord call banner
  below — checked before DND is even consulted.

`Services/Notifications.qml` is the backing singleton. If no notifications
ever appear, see [Troubleshooting](../troubleshooting.md) — usually a
competing daemon re-enabled itself.

## Discord call banner (`Services/DiscordCall.qml`)

An incoming Vesktop call morphs the bar's own clock island (see
[Bar](bar.md)) into a banner — caller avatar, name, "Incoming voice/video" —
instead of showing as a plain toast.

Detection has no real IPC to lean on: Vesktop ships Discord's RPC bridge
disabled by default, and even enabled it only ever lets an app *set* rich
presence, never read call state. What this actually watches is Vesktop's own
desktop notification — the same `org.freedesktop.Notifications` arrival
every other toast in this shell reaches this bar on, matched by app name and
a notification text starting "Incoming call"/"Incoming voice call"/"Incoming
video call". No call, no notification, no banner — including whenever
Vesktop isn't running, or its own call notifications are turned off (see
[Troubleshooting](../troubleshooting.md)).

Join sends Discord's own documented answer shortcut (`Ctrl+Return`,
audio-only — it never turns your camera on) and decline sends Discord's own
decline shortcut (`Escape`), both delivered straight to Vesktop's window
without ever focusing or raising it. Neither is a fake "answer" drawn by this
shell; both are the real shortcut Discord itself already binds. If Vesktop
isn't running, or more than one Vesktop window exists, nothing is sent and
the banner just dismisses.

There's no reliable signal for "already on a call" — Vesktop keeps its audio
streams open permanently, call or no call — so the banner instead just never
re-shows a call once you've pressed Join on it this session.
