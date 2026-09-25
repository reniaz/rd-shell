# Notifications

`rd-shell` owns the `org.freedesktop.Notifications` D-Bus name itself —
`install.sh` masks any competing daemon (`swaync`, `dunst`, `mako`) since it's
an exclusive name and a D-Bus-activated daemon just restarts itself the
moment anything sends a notification.

- **Popups** (`NotificationPopups.qml` / `NotificationCard.qml`) — grouped
  toasts as notifications arrive.
- **History centre** (`NotificationPanel.qml`) — full history, `Super+N`.
- **Bell** (`NotificationBell.qml`) — bar pill, badges unread count.
- **DND** — silences popups, but still lets through hotkey feedback (e.g.
  mic toggle) and an allow-list of apps. Reminders (from `CalendarPopup.qml`)
  still ring with sound even under DND.

`Services/Notifications.qml` is the backing singleton. If no notifications
ever appear, see [Troubleshooting](../troubleshooting.md) — usually a
competing daemon re-enabled itself.
