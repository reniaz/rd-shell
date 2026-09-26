# The shell

`rd-shell` is one Quickshell config (`shell.qml` is the entry point) that
draws a bar per monitor plus a handful of full-screen and popup surfaces. This
section is a tour of each piece.

| Page | Covers |
|---|---|
| [Bar](bar.md) | Left/centre/right pill layout, what each pill shows |
| [Launcher & overview](launcher.md) | App launcher, `hyprlauncher`, the keybind overview |
| [Popups & panels](popups.md) | How the shared popup system works, media/system/network/disk/calendar/power cards |
| [Notifications](notifications.md) | Popups, history centre, DND |
| [OSDs](osds.md) | Keyboard layout, brightness, volume |
| [Edge bar](edge-bar.md) | Per-monitor DDC brightness/contrast strip |
| [Desktop widgets](desktop-widgets.md) | Desktop clock, the Spotify now-playing card, sticky notes |
| [Claude panel](claude-panel.md) | Session table, spend, usage charts, optimize rules |
| [Settings popup](settings.md) | The `✦` pill and `settings.json` |
| [Lock screen](lock-screen.md) | The shell's own lock, `Super+L`, the hyprlock fallback |

## Layout at a glance

```
BarLeft.qml     workspace dots, media pill, sysmon pill, disk, keyboard layout
BarCenter.qml   clock
BarRight.qml    Claude pill, tray, mic, volume, network, notification bell, power
```

`BarWindow.qml` hosts one bar per screen; `BarPopup.qml` and `PopupLoader.qml`
are the shared machinery every pill's card hangs off of, so opening one
closes any other that was open. `BarOverlays.qml` hosts the full-screen
surfaces (launcher, wallpaper switcher, keybind overview, notification panel,
power menu) that sit above the bar rather than dropping from a pill.
`Wallpaper.qml` draws the desktop background itself, on its own layer, and
runs the crossfade when the wallpaper changes. `WlLock.qml` and
`LockSurface.qml` are the shell's own lock screen, separate from anything
above — see [Lock screen](lock-screen.md).
