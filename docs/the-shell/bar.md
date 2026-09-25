# Bar

One bar per monitor (`BarWindow.qml`), split into three groups.

## Left (`BarLeft.qml`)

- **Workspace dots** (`WorkspaceDots.qml`) — current workspace, per monitor.
- **Media pill** — now playing, with a `cava` audio visualizer
  (`CavaBars.qml`/`CavaRing.qml`) fed from Spotify's audio only (the same
  feed every other visualizer in the shell uses). Opens `MediaPopup.qml`.
- **System monitor pill** — CPU/GPU/RAM, colour-coded by load and
  temperature. Opens `SysPopup.qml`.
- **Disk pill** — opens `DiskPopup.qml`.
- **Keyboard layout pill** — only shown when more than one layout is
  configured (`input.kb_layout` in `hypr/hyprland.lua`); `Ctrl+Shift+Space`
  cycles it.

## Centre (`BarCenter.qml`)

- **Clock**, with reminders set from its calendar (`CalendarPopup.qml`) —
  timers and alarms ring as notifications with sound, DND included.

## Right (`BarRight.qml`)

- **Claude pill** — see [Claude panel](claude-panel.md). No bind by default.
- **Tray** (`TrayItems.qml`).
- **Mic pill** — mute state, `Ctrl+Shift+M` or `XF86AudioMicMute` to toggle.
- **Volume pill** — opens a volume slider/popup (`MediaVolume.qml`,
  `VolumeSlider.qml`).
- **Network pill** — online/offline; opens `NetworkPopup.qml` with live
  down/up speed, byte counters and a 60s sparkline.
- **Notification bell** — see [Notifications](notifications.md).
- **Power pill** — logout/reboot/shutdown/lock over `hyprshutdown`
  (`PowerMenu.qml`).

Every pill hangs its card from a shared popup component (`Pill.qml` +
`PopupLoader.qml`/`BarPopup.qml`) — see [Popups & panels](popups.md) for how
that's wired.

## Contrast watching

`BarContrastWatch.qml` and `BarOsdWatch.qml` keep the bar and OSDs legible
against whatever's directly behind them, independent of the dynamic-colour
pass described in [Theming](../theming/README.md).
