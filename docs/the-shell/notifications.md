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
[Bar](bar.md)) into a banner — caller avatar, name, "Incoming call" —
instead of showing as a plain toast.

Detection has no real IPC to lean on: Vesktop ships Discord's RPC bridge
disabled by default, and even enabled it only ever lets an app *set* rich
presence, never read call state — and Vesktop sends no desktop notification
for a call either, so there's nothing on `org.freedesktop.Notifications` to
watch. What actually carries the ring is Vencord's own **XSOverlay** plugin:
enabled (see [vesktop](../dotfiles/vesktop.md#call-banner-xsoverlay-plugin)),
it already opens a WebSocket straight from the discord.com page on every
call update and posts one small notification-shaped message. That message
goes to `scripts/vencord-call-bridge.py`, a local WebSocket server this
shell starts and restarts as a `Process` (`127.0.0.1:42070`, accepting only
an Origin of discord.com/ptb/canary), which turns a genuine ring into one
line of stdout the bar reads — a message notification uses the same
envelope and is dropped there, so no message content ever reaches this
shell. No ring event, no banner — including whenever Vesktop isn't running,
the plugin is off, or the port is already taken (see
[Troubleshooting](../troubleshooting.md)).

Because it doesn't ride on a desktop notification, the banner shows even
with DND on — checked before DND is even consulted, as above. Two things it
can't do, for the same reason: Vencord's own message to the plugin never
says voice or video, so the label is always the generic "Incoming call";
and nothing ever reports a ring *stopping*, so the banner simply times out
on its own rather than tracking whether the call is still ringing.

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
