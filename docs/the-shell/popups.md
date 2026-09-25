# Popups & panels

Every bar pill opens its card through the same shared component
(`Pill.qml` → `PopupLoader.qml` → `BarPopup.qml`), so only one panel is ever
open at a time and they share entrance/exit animation and positioning logic.
Full-screen surfaces (launcher, wallpaper switcher, keybind overview,
notification panel, power menu) go through `BarOverlays.qml` instead, since
they cover the whole screen rather than hanging off a pill.

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

## Calendar (`CalendarPopup.qml`)

Set timers and alarms from here; they ring as notifications with sound, DND
included.

## Power (`PowerMenu.qml`)

Logout / reboot / shutdown / lock, dispatched over `hyprshutdown`.

## Audio Disk OSD note

`AudioOsd.qml`, `BrightnessOsd.qml` and `KeyboardLayoutOsd.qml` are a
different, lighter-weight surface than the popups above — see [OSDs](osds.md).
