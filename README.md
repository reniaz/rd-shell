<div align="center">

# ✦ rd shell ✦

**A personal [Quickshell](https://quickshell.outfoxxed.me) configuration.**

<sub>bar · notifications · launcher · osd · lockscreen</sub>

![QML](https://img.shields.io/badge/QML-41CD52?style=flat-square&logo=qt&logoColor=white)
![Wayland](https://img.shields.io/badge/Wayland-FFBC00?style=flat-square&logo=wayland&logoColor=black)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

<img src="assets/preview.png" alt="preview" width="90%">

</div>

---

## Features

| | |
|---|---|
| **Bar** | workspaces, media, clock, tray, network, audio, mic, keyboard layout, disk |
| **System** | CPU / GPU / memory pill, per-part detail, process killer |
| **Network** | throughput card under the pill: live down/up speed, bytes in and out, a sparkline of the last minute |
| **Notifications** | grouped popups + history center, do-not-disturb that WhatsApp and reminders ring through |
| **Reminders** | timers and alarms set from the calendar, they ring as notifications |
| **OSD** | keyboard layout overlay |
| **Power** | logout / reboot / shutdown / lock menu, over `hyprshutdown` |
| **Claude** | live session table, lifetime spend, usage charts, cost rules |
| **Theming** | one color file, live reload |

## Claude panel

Clicking the bar's Claude pill hangs a panel under it, with four tabs. There is no
key for it by default — see [Keybinds](#keybinds) if you want one.

**Sessions** — every live `claude` process on the machine: what it is doing right
now, what it is blocked on, its context fill, the plan it is following and the
subagents it has spawned. Click a row to expand a full transcript scan of that
session; click its title to focus the terminal window it is running in.

**Usage** — lifetime account spend. Not the day's message count and not
`~/.claude.json`'s `lastCost`, which describes a single session and reads two
orders of magnitude low: this is every transcript the account has ever written,
broken down by project and by model, with the plan's rate limits underneath.

**Statistics** — the same history as charts: spend per day, cumulative spend, the
model mix, where the tokens actually go, the hours and weekdays you work, which
tools get used, and the sessions that cost the most.

**Optimize** — the token-budget rules that make all of the above smaller, each one
a line in `settings.json` or in `CLAUDE.md`, applied and reverted from the panel.
It reads the two files rather than remembering what it wrote, so a rule you undid
by hand shows as undone.

Every tab keeps its last reading when the panel closes, so reopening paints the
numbers you left rather than sweeping up from zero while the next scan runs.

The four data sources behind them are shell scripts, so nothing here starts a
`claude` process to ask a question:

| Script | Reads | Costs |
|---|---|---|
| `scripts/claude-status.sh` | `~/.claude` state files | ~40ms, polled every 2s |
| `scripts/claude-session.sh` | one whole transcript | ~0.2s, only while a row is open |
| `scripts/claude-global.sh` | every transcript ever written | seconds cold, ~0.4s warm; once at startup, then every 2 min while the panel is open |
| `scripts/claude-usage.sh` | the `/usage` endpoint | one request per minute |

`claude-global.sh` caches its parse per file on `(mtime, size)` in
`~/.cache/qs-bar/`, so a refresh after one active session re-reads one
transcript rather than the 200MB corpus. Cost comes from the CLI's own
`cost-state` ledger — the figure `/cost` prints — wherever a transcript carries
one, and from token counts at published prices everywhere else; the per-day and
per-model breakdowns are always derived and then scaled onto the authoritative
total, so the parts of a session sum to the whole it was billed at.

## System monitor

One pill, beside whatever is playing: processor load and temperature, graphics
VRAM and temperature, memory in use. Each icon is green while its part of the
machine is idle, `#b86e38` past three quarters, red past ninety — or, for the
two figures that are temperatures, past 75°/90° on the CPU and 70°/84° on the
card, which is where it starts throttling itself.

Clicking the pill hangs a panel under it with a tab per part:

**Processor** — load, every logical thread as its own column, package
temperature, average clock, load averages, and the processes responsible.

**Graphics** — both devices. The discrete card reports temperature, VRAM and fan
speed; how busy it is lives in NVML, which means `nvidia-smi`, which the open
driver package does not install, so it is not guessed at. The integrated Radeon
reports exactly that figure through hwmon, along with package power.

**Memory** — resident, swap, available and cache, and the processes holding it.

Any row in either process list can be ended from the panel: hovering shows the
control, and it asks once before firing, offering SIGTERM and SIGKILL as
separate buttons rather than one button with a modifier.

| Script | Reads | Costs |
|---|---|---|
| `scripts/sysmon.sh` | `/proc`, hwmon, `nvidia-settings` | ~80ms, polled every 2s |
| `scripts/sysmon-procs.sh` | two `top` passes 0.2s apart | ~0.5s, only while the panel is open |

CPU percentages come from raw `/proc/stat` jiffy counters differenced against
the previous sample rather than from a second reading taken inside the script,
so a poll costs one pass over `/proc` and no sleep. `top` and not `ps` for the
process lists: `ps` reports a process's CPU share averaged over its whole
lifetime, which for anything long-running is a number about last week.

## Network

The pill says whether you are online and on which connection. Left-clicking it
hangs a card under it that says whether anything is actually moving: download and
upload speed, the byte counters the kernel has been adding up since the interface
came up, and a sparkline of the last minute with the download filled and the
upload drawn over it. Right-click still opens the NetworkManager KCM.

NetworkManager knows the name a connection was given; it does not know a rate, so
the throughput is read straight from `/sys/class/net/<device>/statistics/` — two
counters, sampled a second apart, the speed being the difference. Sampling only
runs while the card is open, and the first sample after opening publishes no rate
at all, because one counter has nothing to be subtracted from. The history
outlives the card, so closing it pauses the graph and reopening continues the same
line instead of drawing a new one from nothing.

## Requirements

- Fedora 44. This repo also carries `hypr/`, the Hyprland config it was built
  against (Lua config, `hl.*` API) — `install.sh` installs Hyprland itself
  from the `lionheartp/Hyprland` COPR along with the bar, so a fresh box
  needs nothing pre-installed.
- [`quickshell`](https://quickshell.outfoxxed.me) — from the same COPR
- `matugen` (dynamic colour, from the same COPR), `pipewire` + `wireplumber`,
  `NetworkManager`, `jq`, `gawk`, `procps-ng`, `ImageMagick`
- Two fonts: **Material Symbols Rounded** for every icon, **caelusevka** for every label
- Optional: `nvidia-settings`/`libva-nvidia-driver` (NVIDIA-only), `brightnessctl`
  (brightness OSD), `cava`+`pipewire-utils` (visualizer), `ddcutil`, `btop`,
  `libcanberra-gtk3` (the sound a reminder makes; it still notifies without it),
  the Claude Code CLI (the Claude panel is empty without `~/.claude`)

`install.sh` checks and installs all of it, on both the bar and the Hyprland
side — see [`READ DAS HIER.md`](READ%20DAS%20HIER.md).

## Install

```bash
git clone https://github.com/reniaz/rd-shell ~/coding/qs-bar
cd ~/coding/qs-bar && ./install.sh
```

**[`READ DAS HIER.md`](READ%20DAS%20HIER.md)** is the full setup guide — read it first.

`install.sh` is the one-time setup, for the compositor and the bar together: it
installs every package and COPR both need, builds `fetchit` and (optionally)
`wayvibes` from source, symlinks `~/.config/quickshell/rd-shell` and puts
`hypr/`'s configs and app dotfiles in place, adds the `hyprexpo` plugin, clones
in the wallpapers, renders the first colour theme so nothing points at a
matugen file that does not exist yet, masks any competing notification daemon,
and repairs the system-level faults that leave PipeWire dead at boot. It is
safe to re-run — every step checks before it changes anything.

Autostart with `launch.sh`, not `qs` directly. It brings the audio stack up and
waits for the graph before starting the shell, which otherwise reads an empty
graph and shows 0% volume with no mic for the rest of the session.

```ini
exec-once = ~/.config/quickshell/rd-shell/launch.sh

# or

hl.exec_cmd("~/.config/quickshell/rd-shell/launch.sh")
```

## Structure

```
rd-shell/
├── shell.qml            # entry point: one Bar per screen, four IPC handlers
├── Bar.qml              # the bar itself — pill order, panel loaders
├── BarPopup.qml         # shared card/notch/grow/dismiss for every panel
├── PopupLoader.qml      # holds a popup's window open long enough to play its exit
├── CalendarPopup.qml    # the month and its reminders, hung under the clock on right-click
├── DiskPopup.qml        # per-filesystem breakdown, under the disk pill
├── MediaPopup.qml       # every loaded player, play/pause each one
├── NetworkPopup.qml     # down/up speed, bytes in and out, under the network pill
├── Sys*.qml             # system monitor pill and its tabbed panel
├── Claude*.qml          # Claude pill panel: sessions, usage, statistics, optimize
├── Notification*.qml    # popups, history centre, bell
├── Config/
│   ├── Colors.qml       # palette — everything reads from it, hot-reloads on save
│   └── Format.qml       # bytes, durations, temperatures
├── Services/            # singletons: Audio, Network, Disk, SysMon, Claude*, …
├── scripts/             # the shell scripts the services poll
├── assets/fonts/        # caelusevka, bundled because no repo ships it
├── assets/fontconfig/   # keeps the icon family resolving to the full font
├── install.sh           # one-time setup
└── launch.sh            # autostart entry — brings audio up, then execs qs
```

## Theming

Edit `Config/Colors.qml` — everything reads from it and hot-reloads on save.
The palette is derived from the [system24](https://github.com/refact0r/system24)
*caelus* theme, with `#b86e38` as the main accent.

```qml
readonly property color accent: "#b86e38"   // main accent
readonly property color bg:     "#000000"   // pill background
readonly property color fg:     "#f8f5f2"   // label text
```

`templateColor1`…`templateColor12` hold the rest of the caelus palette, unassigned
and ready to name as new widgets need them.

## Dynamic colour

The bar follows the wallpaper by default: every switch runs matugen and
`Config/Colors.qml` reads its palette instead of the fixed caelus theme above.
The switch lives in `settings.json` next to `shell.qml` (written by
`Services/Settings.qml`, never committed):

```json
{ "dynamicColour": false }
```

Set it to `false` for the static caelus palette, `true` or no file at all for
dynamic colour. The settings popup has no toggle for it right now. The change
applies live: `Services/Settings.qml` watches the file and re-runs the colour
pass. Wallpaper switches are live too, since they arrive through `FileView`,
which watches its own file.

One switch, three surfaces: the bar, the semantic pills and Hyprland's window
borders all read `dynamicColour`. `scripts/wallpaper-apply.sh` applies the
border through `hyprctl eval` (a Lua config refuses `hyprctl keyword`), so
`hyprland.lua` keeps its caelus literals and a fresh Hyprland start is already
the static look. Borders follow on the next wallpaper change or login, not the
instant the switch is flipped.

What follows the wallpaper and what does not:

| | dynamic mode |
|---|---|
| surfaces, accent, label text, island edge | matugen roles outright |
| network, keyboard, media, notification pills | matugen roles outright |
| volume (green), mic and power (red), `ok`/`warn`/`error`, the 12 chart slots | hue kept, saturation and brightness borrowed |

The second row is `Wal.reshade()`. Volume is green and mic is red at every
hour of the day — those are read at a glance rather than puzzled over, which
only works while the colour is the one it was yesterday — so the wallpaper
moves their register without touching their hue.

Dynamic mode runs on matugen, through `Config/Wal.qml`. Every wallpaper switch
re-renders `matugen/colors.json` into `~/.cache/rd-shell/matugen.json` and the
bar follows it without a restart. matugen returns Material You tonal roles, so
surfaces and accent stay distinguishable. If matugen is missing or its output
has not been written yet, the switch stays inert and the caelus palette holds.

## Keybinds

| Key | Action |
|---|---|
| <kbd>Super</kbd> + <kbd>M</kbd> | Power menu |
| <kbd>Super</kbd> + <kbd>N</kbd> | Notification center |
| <kbd>Super</kbd> + <kbd>L</kbd> | Lock (`hyprlock`, not part of this config) |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>M</kbd> | Toggle microphone |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>Space</kbd> | Next keyboard layout — what the layout OSD reacts to |
| <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>↑</kbd> | Screenshot a region |
| <kbd>Super</kbd> + <kbd>H</kbd> | Keybind cheat sheet — rofi, built from `hyprctl binds` |

The Claude and system panels have no bind of their own; they open from their pills, or
from `qs ipc -c rd-shell call claude toggle` / `... call system toggle` if you want to
give them one. Every bind above is set in the compositor, not here — the exact lines
are in [`READ DAS HIER.md`](READ%20DAS%20HIER.md).

---

<div align="center">
<sub>Built with Quickshell · MIT</sub>
</div>
