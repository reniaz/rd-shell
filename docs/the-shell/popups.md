# Popups & panels

Every bar pill opens its card through the same shared component
(`Pill.qml` → `PopupLoader.qml` → `BarPopup.qml`), so only one panel is ever
open at a time and they share entrance/exit animation and positioning logic.
Full-screen surfaces (launcher, wallpaper switcher, keybind overview,
notification panel, power menu) go through `BarOverlays.qml` instead, since
they cover the whole screen rather than hanging off a pill. The utility tray
below is one of these too, just instantiated straight from `shell.qml`
instead.

## System monitor (`SysPopup.qml`)

Opened from the system monitor pill (`Ctrl+Shift+Esc` also opens it directly).
Top: three ring gauges (CPU/GPU/RAM, `SysRing.qml`). Below: a tabbed panel
(`SysCpuTab.qml` / `SysGpuTab.qml` / `SysMemTab.qml`), switched with `←`/`→`
— the last tab viewed is remembered across opens.

- Every tab keeps a 2-minute history graph.
- **Processor** — per-core load and clocks (`SysCores.qml`).
- **Graphics** — the NVIDIA card read straight off `libnvidia-ml.so.1`
  through `ctypes` (utilisation, clocks, power vs. its limit, fan, P-state,
  encode/decode), plus the Radeon iGPU. No NVIDIA driver installed means the
  NVIDIA rows simply stay hidden.
- **Memory** — a stacked used/cache/free bar (`SysStackMeter.qml`) and the
  zram line.
- Every tab ends in a process list (`SysProcList.qml`/`SysProcRow.qml`)
  grouped by app (`name ×N`), CPU normalised to the whole CPU, sortable by
  clicking the CPU/Mem/VRAM column headers. Click a row to expand it (command
  line, user, threads, runtime) with **End** (SIGTERM) and **Force**
  (SIGKILL) actions.

One persistent Python sampler, `scripts/sysmon.py` (stdlib + `ctypes`, no
forks per tick), feeds all of it. The per-process scan only runs while the
popup is open.

## Media (`MediaPopup.qml`)

Now-playing controls, art, artist(s) with featured artists, seekable
progress, shuffle/previous/play-pause/next/loop, volume.

## Network (`NetworkPopup.qml`)

Live down/up speed, byte counters, a 60s sparkline — read straight from
`/sys/class/net`, no daemon in between.

## Disk (`DiskPopup.qml`)

Disk usage readout.

## Dashboard (`NotchDashboard.qml`)

Opened by right-clicking the clock pill (left-click is unchanged) in every
bar style, or the notch tab at the bar's horizontal centre under `corners` —
`qs ipc -c rd-shell call dashboard toggle` opens/closes it from anywhere,
same IPC shape every other singleton here uses. One screen's panel at a
time, same gate the power menu uses.

- A top row of quick toggles — Wi-Fi reads `Services/Network.qml` and opens
  the NetworkManager editor; Bluetooth and the three environment toggles
  (night light, caffeine, game mode) are disabled stubs with no backend yet.
- A now-playing strip (`DashMediaCard.qml`, composed from `MediaArt.qml`/
  `MediaButton.qml`), the calendar (`DashCalendarPane.qml`, below) and a
  short notification peek (`DashNotifications.qml`, reusing
  `NotificationCard.qml`) on the left.
- Brightness on a vertical track (`EdgeSlider.qml`) and volume/mic
  (`VolumeSlider.qml`) on the right.

Pin it (the panel's own "keep" glyph, or `BarLeft.qml`'s pin icon in
`corners`) to stop click-outside from closing it — Escape still closes it
either way. Built on `BarPopup` like every popup above, so it joins the same
fused silhouette (`Blob.qml`) the notch tab's own island draws into, with no
hand-drawn seam of its own.

### Calendar (`DashCalendarPane.qml`)

The calendar lives in the dashboard now, not in a bar popup of its own —
`CalendarPopup.qml` is retired. `DashCalendarPane.qml` is `CalendarGrid.qml`
(the 42-cell month grid, its own file so a future popup could reuse it)
plus, below it, either the picked day's agenda or — with no day picked,
which is how the pane opens — **Upcoming**, the next few reminders with
their countdowns. Timers and alarms still ring as notifications with sound,
DND included (`Services/Reminders.qml`).

- **Grid** — six weeks always shown, so paging never changes the card's
  height. Follows the Desktop settings page's week-start and week-number
  choices (see [Settings](settings.md)). Each day can carry up to 3 small
  dots under its number — one per reminder landing that day, muted for an
  all-day one, accented for a timed one-off or a repeating series — then a
  "+N" once there are more than 3. Today is a filled ring; a picked day (if
  it isn't also today) is an outlined one.
- **Picking a day** — click it, or arrow/page the keyboard focus onto it
  (below); clicking the same day again — or the agenda header's own
  "Upcoming" link — clears the pick and goes back to Upcoming.
- **Agenda** — the picked day's reminders in time order, each inline:
  text is editable in place, the time/all-day label, a repeat chip that
  cycles through `Reminders.repeats` on click, a snooze action (10 minutes),
  and delete.
- **Upcoming** — the same snooze/delete pair on a flatter list, soonest
  first, when no day is picked.
- **Compose row** — text, a `HH:MM` field (hidden behind the all-day
  toggle), repeat chips, all-day, add — plus the 5/15/30-minute quick timers
  underneath, unchanged from the old popup's own.
- **Keys** — the grid takes keyboard focus as soon as the dashboard opens:
  `←`/`→`/`↑`/`↓` move the picked day, `PageUp`/`PageDown` page the month,
  mouse wheel over the grid does the same, `T` jumps back to today. A
  one-line legend under the grid repeats this.

## Power (`PowerMenu.qml`)

Logout / reboot / shutdown / lock, dispatched over `hyprshutdown`.

## Utilities tray (`UtilityTray.qml`)

`Ctrl+Alt+U` (`qs ipc -c rd-shell call utilities toggle`) opens a small
keybind-only popup, no bar pill, with three independent screen-reading tools:

- **Read text** — OCR via `tesseract`, on a `slurp`-selected region captured
  with `grim -g`. No translation step (see the separately-tracked
  translate-popup idea for that). Lives in `Services/Ocr.qml`, which owns the
  whole slurp/grim/tesseract pipeline on its own so that idea can drive it
  directly too. `tesseract` is not installed by `install.sh` today — the row
  shows disabled with `sudo dnf install tesseract` as its hint until it is,
  re-checked (`command -v`) every time the tray opens, no shell restart
  needed.
- **Pick colour** — `hyprpicker -a` (its own crosshair selector, not `slurp`);
  `-a` autocopies the hex it picks, so nothing here calls `wl-copy` a second
  time for this one.
- **Scan QR / barcode** — the same `slurp` + `grim -g` region grab as "Read
  text", decoded with `zbarimg --raw -q` (package `zbar-tools`).

Picking a tool hides the tray so the region-select/colour-pick tool underneath
it can see the real screen, then brings it back once there is something to
show: the recognised text / decoded payload (with a Copy action, and an Open
action when a QR payload is an `http(s)` URL, via `xdg-open`) or the picked
colour as a swatch + hex. The result is also copied to the clipboard with
`wl-copy` as soon as it lands. Cancelling the region/colour select (`Esc`)
is quiet — no error, the tray just reopens on the idle tool list. All of this
state lives in `Services/Utilities.qml`, not in the popup file itself.

## Audio Disk OSD note

`AudioOsd.qml`, `BrightnessOsd.qml` and `KeyboardLayoutOsd.qml` are a
different, lighter-weight surface than the popups above — see [OSDs](osds.md).
