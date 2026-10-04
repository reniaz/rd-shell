# Bar

One bar per monitor (`BarWindow.qml`), split into three groups.

## Left (`BarLeft.qml`)

- **Workspace dots** (`WorkspaceDots.qml`) — current workspace, per monitor.
  The active dot travels with a real spring, not an eased tween, and a
  workspace Hyprland marks urgent pulses until you switch to it. The dot
  skin and the **beat glow** (a faint accent edge on the active dot while
  something is playing, off by default) are both settings-app toggles now
  (`workspaceSkin`/`workspaceBeatGlow` in `settings.json`, Bar page).
- **Media pill** — now playing, with a `cava` audio visualizer
  (`CavaBars.qml`/`CavaRing.qml`) fed from every playing app except
  wayvibes. A title too long for the pill scrolls continuously (`MarqueeText.qml`)
  instead of eliding, and stops while paused. Opens `MediaPopup.qml`. The EQ
  bars beside it are a separate settings-app toggle (`cavaPill`, default on) —
  wrapped in their own `Item` rather than overriding `CavaBars.qml`'s own
  `visible` binding, so the EQ's self-collapse-when-silent behaviour survives
  being turned fully off and back on.
- **System monitor pill** — CPU/GPU/RAM, colour-coded by load and
  temperature. Opens `SysPopup.qml`. Settings-app toggle (`systemPill`,
  default on) on top of its own `SysMon.available` self-gate.
- **Disk pill** — opens `DiskPopup.qml`.
- **Keyboard layout pill** — only shown when more than one layout is
  configured (`input.kb_layout` in `hypr/hyprland.lua`); `Ctrl+Shift+Space`
  cycles it.

## Centre (`BarCenter.qml`)

- **Clock**, with reminders set from its calendar (`CalendarPopup.qml`) —
  timers and alarms ring as notifications with sound, DND included. Format
  (24h/12h, `clockFormat`) and whether it shows seconds (`clockSeconds`,
  default off) are settings-app toggles (Bar page) — both live in
  `Services/Time.qml`, the one clock singleton the bar pill, the desktop
  clock (`DesktopClock.qml`) and the lock screen (`LockSurface.qml`) all
  read, so the three never disagree on either the time or how it's
  written. `clockSeconds` also drops `Time.qml`'s own `SystemClock`
  precision to once a second — only while it's on, so leaving it off costs
  no extra wakeups.
- **Discord call banner** — the clock island itself grows and morphs into an
  incoming-call banner (`DiscordCallBanner.qml`) rather than dropping a
  separate card; see [Notifications](notifications.md) for how detection and
  the join/decline shortcuts actually work.

## Right (`BarRight.qml`)

- **Claude pill** — see [Claude panel](claude-panel.md). No bind by default.
- **Tray** (`TrayItems.qml`). Settings-app toggle (`trayPill`, default on) on
  top of its own self-gate (hidden whenever nothing survives the tray's own
  filter).
- **Mic pill** — mute state, `Ctrl+Shift+M` or `XF86AudioMicMute` to toggle.
  Muting overlays a red slash on the glyph; unmuting springs it back with a
  little swing (`MuteGlyph.qml`) — the pill's own width never changes either
  way.
- **Volume pill** — opens a volume slider/popup (`MediaVolume.qml`,
  `VolumeSlider.qml`), same mute slash/swing as the mic pill.
- **Bluetooth pill** — only shown when the machine has a Bluetooth adapter.
  The icon shows off / on / a device connected; left-click turns the adapter
  on or off, right-click opens KDE's Bluetooth settings for pairing
  (`kcmshell6 kcm_bluetooth`, package `bluedevil`). Turning on a
  soft-blocked adapter lifts the rfkill block first. To hide the pill on a
  machine that has an adapter you never use, set `"bluetoothPill": false` in
  `~/.config/quickshell/rd-shell/settings.json`, or flip it in the settings
  app's Bar page (Pills card) — both write the same key.
- **Network pill** — online/offline; opens `NetworkPopup.qml` with live
  down/up speed, byte counters and a 60s sparkline. Settings-app toggle
  (`networkPill`, default on) — unlike the pills above it had no visibility
  gate of its own before this.
- **Notification bell** — see [Notifications](notifications.md).
- **Power pill** — logout/reboot/shutdown/lock over `hyprshutdown`
  (`PowerMenu.qml`).

Every pill hangs its card from a shared popup component (`Pill.qml` +
`PopupLoader.qml`/`BarPopup.qml`) — see [Popups & panels](popups.md) for how
that's wired. A click also lifts a small circle of ink from wherever the
pointer actually pressed (`RippleLayer.qml`), clipped to the pill's own
rounded shape, alongside the existing hover/press wash. Settings-app toggle
(`pillRipple`, default on, Bar page's Look card) — off, every pill falls
back to the flat press wash it always had before the ripple existed.

Two more Look-card sliders, both backed by `Config/Caelus.qml` tokens of the
same name and clamped there too (a hand-edited `settings.json` isn't bound
by the slider's own range): **Edge margin** (`barMargin`, 0-24px, default
14) is the gap between the outer islands and the screen's left/right edges.
**Surface opacity** (`barOpacity`, 0.30-0.70, default 0.45) is the
translucency shared by every island and popup body — the slider's floor is
kept well clear of the `ignore_alpha = 0.2` hyprland.lua's layer rules use,
since a surface at or below that threshold silently loses its blur.

## Bar styles

`Ctrl+Alt+B` opens a switcher, styled like the wallpaper switcher, to pick the
bar's shape:

- **Islands** — three floating plates with the wallpaper showing between them.
  The default.
- **Full bar** — one solid strip across the top edge.
- **Corner dashboard** — the clock joins the right-hand group into one merged
  island, leaving a left island, a wide right island, and a small notch tab
  flush with the top centre. Clicking the tab toggles a dashboard panel
  (`Services/Dashboard.qml`, `NotchDashboard.qml`); a pin icon appears at the
  end of the left group while it's open, to keep it from closing on the next
  click outside.

The switch animates, and the choice is remembered (`barStyle` in
`settings.json`, `islands`, `full` or `corners`). To open it from a script:
`qs ipc -c rd-shell call barstyle toggle`.

## Contrast watching

`BarContrastWatch.qml` and `BarOsdWatch.qml` keep the bar and OSDs legible
against whatever's directly behind them, independent of the dynamic-colour
pass described in [Theming](../theming/README.md).
