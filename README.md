<div align="center">

# ✦ rd shell ✦

**A Quickshell bar/desktop shell for Hyprland, plus the author's full rice.**

<sub>bar · notifications · launcher · osd · lockscreen · matugen theming</sub>

![QML](https://img.shields.io/badge/QML-41CD52?style=flat-square&logo=qt&logoColor=white)
![Wayland](https://img.shields.io/badge/Wayland-FFBC00?style=flat-square&logo=wayland&logoColor=black)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

</div>

---

`rd-shell` is a [Quickshell](https://quickshell.outfoxxed.me) (QML) bar built
for a Lua-configured [Hyprland](https://hyprland.org) on Fedora 44. This repo
is the whole rice: the bar, the Hyprland config it was built against
(`hypr/`), app dotfiles wired to [matugen](https://github.com/InioX/matugen)
wallpaper colours (`dotfiles/`), the author's wallpapers, and one installer
(`install.sh`) for a fresh box.

**Stack at a glance:** Hyprland · Quickshell · matugen · ghostty · rofi ·
hyprlauncher · fetchit · btop · cava · nvim · yazi · vesktop · spicetify.

GitHub: [reniaz/rd-shell](https://github.com/reniaz/rd-shell)

## Features

**Bar** — workspace dots, media pill with cava, CPU/GPU/RAM readout, clock
with reminders, Claude pill, keyboard layout, disk, tray, mic, volume,
network, notification bell, power. Every panel hangs from its pill through
a shared popup component.

**Launcher & overview** — a QML-native app launcher (`Super+Space`,
search-as-you-type, not rofi) plus `hyprlauncher` (`Super+R`) as a second,
independent launcher. `Super+K` opens a searchable overview of every
Hyprland bind inside the bar — type to filter, `Enter` or a click runs the
selected one. `Super+H` opens the same bind list as a rofi sheet instead.

**Wallpaper switcher & dynamic colour** — `Ctrl+Alt+F` opens a fullscreen
coverflow over `~/Pictures/wall`; picking one re-renders matugen, and the
bar, Hyprland's borders and the rest of the rice follow, no restart. On by
default — see [Theming](#theming--dynamic-colour).

**Notifications** — grouped popups plus a history centre, DND that still
lets through hotkey feedback and an allow-list of apps.

**Reminders** — timers and alarms set from the clock's calendar, ringing as
notifications with sound, DND included.

**System monitor** — one pill (CPU/GPU/RAM), colour-coded by load and
temperature, opening a card with three ring gauges (CPU/GPU/RAM) up top and
a tabbed panel (Processor / Graphics / Memory) switched with `←`/`→` (the
last tab is remembered across opens). Every tab keeps a 2-minute history
graph; Processor adds per-core load and clocks; Graphics reads the NVIDIA
card straight off NVML (utilisation, clocks, power vs. its limit, fan,
P-state, encode/decode) plus the Radeon iGPU; Memory draws a stacked
used/cache/free bar and the zram line. Every tab ends in a process list
grouped by app (`name ×N`), CPU normalised to the whole CPU, sortable by
clicking the CPU/Mem/VRAM headers — click a row to expand it (command line,
user, threads, runtime) with End (SIGTERM) and Force (SIGKILL). One
persistent Python sampler, `scripts/sysmon.py` (stdlib + `ctypes`, no forks
per tick), feeds all of it; the per-process scan only runs while the popup
is open.

**Network** — online/offline pill; a card shows live down/up speed, byte
counters and a 60s sparkline read straight from `/sys/class/net`.

**Claude panel** — no key by default (bind `qs ipc -c rd-shell call claude
toggle` yourself). Four tabs: live session table (what's running, context
fill, plan, subagents), lifetime spend from every transcript ever written,
spend/usage charts, and token-budget optimize rules applied from
`settings.json`/`CLAUDE.md`. All four read state on disk — nothing here
starts a `claude` process to answer a question.

**OSDs** — keyboard layout, brightness, volume.

**Edge bar / DDC** — a hover-revealed strip on a monitor's outer edge,
caelestia-inspired, carrying per-monitor brightness/contrast over DDC/CI for
desktop displays with no backlight device, via `ddcutil`.

**Power** — logout / reboot / shutdown / lock, over `hyprshutdown`.

**Dzuma** — merch-drop pill, fed by a private scraper; optional, inert
without it.

## Install

```bash
git clone https://github.com/reniaz/rd-shell ~/coding/qs-bar
cd ~/coding/qs-bar && ./install.sh
```

`install.sh -y` (or `--yes`) assumes yes to every prompt instead of asking.
It's the one installer for compositor and bar together, safe to re-run —
every step checks before it changes anything:

- enables the COPRs Hyprland, Quickshell and matugen come from
  (`lionheartp/Hyprland`, `errornointernet/quickshell`) plus `ghostty`/`yazi`'s
  own COPRs, and RPM Fusion if an NVIDIA card is detected
- installs every package both configs shell out to (required vs. optional
  per missing binary), builds `fetchit` and optionally `wayvibes` from
  source (neither has a Fedora package)
- installs Material Symbols Rounded (downloaded on demand), bundled
  caelusevka, and the Bibata cursor theme
- symlinks the repo to `~/.config/quickshell/rd-shell`, links `hypr/`'s
  configs and every app dotfile into `~/.config`, recreates the
  `keybinds.sh`/`mic-toggle.sh`/`screenshot.sh` symlinks Hyprland calls
- sets btop's theme to matugen, ghostty as the default terminal, masks
  competing notification daemons, patches the PipeWire drop-in that can
  crash the audio stack at boot, enables `hypridle`
- clones the LainOS wallpapers, copies this repo's own on top, adds the
  `hyprexpo` plugin, renders the first matugen theme so nothing points at a
  colour file that doesn't exist yet

**Left for you to do by hand** (from the end-of-run summary):

- edit `hl.monitor(...)` and the `MAIN`/`SECOND` output names in
  `hypr/hyprland.lua` for your monitors (or delete them, auto-detect)
- delete `hl.env("LIBVA_DRIVER_NAME", "nvidia")` with no NVIDIA card
- set `input.kb_layout` to your own layouts — a second layout is what makes
  the keyboard pill and its OSD appear at all
- Dzuma needs a private scraper, optional, inert without it
- install vesktop / flatpak Spotify / flatpak Signal / wayvibes soundpacks
  yourself if wanted — their matugen themes are already linked
- edit `dotfiles/fetchit/init.lua`'s hand-typed os/gpu lines for your machine
- one-time root setup if the login-screen wallpaper should follow too
- log out and pick "Hyprland" at the login screen

Autostart with `launch.sh`, never `qs` directly — it brings the audio graph
up first, otherwise the bar starts at 0% volume with no mic all session:

```ini
exec-once = ~/.config/quickshell/rd-shell/launch.sh
```

## Keybinds

| Combo | Action |
|---|---|
| `Super+Q` | Terminal (ghostty) |
| `Super+W` | Close window |
| `Super+E` | File manager (dolphin) |
| `Super+B` | Browser (firefox) |
| `Super+Space` | App launcher (shell-native) |
| `Super+R` | Launcher (hyprlauncher) |
| `Super+H` | Keybind cheat sheet (rofi) |
| `Super+K` | Keybind overview (search, in-bar) |
| `Ctrl+Alt+F` | Wallpaper switcher |
| `` Super+` `` | Workspace overview (hyprexpo) |
| `Super+Shift+S` | Showcase layout (fetchit/btop/cava/yazi) |
| `Super+M` | Power menu |
| `Super+N` | Notification panel |
| `Super+L` | Lock the session |
| `Ctrl+Shift+Esc` | System monitor |
| `Ctrl+Shift+M` | Mute/unmute microphone |
| `Ctrl+Shift+Space` | Cycle keyboard layout |
| `Ctrl+Alt+↑` | Screenshot a region |
| `Super+V` | Float / tile window |
| `Super+P` | Pseudotile window |
| `Super+F` | Fullscreen window |
| `Super+Shift+F` | Fake fullscreen (keeps the bar) |
| `Super+J` | Toggle split direction |
| `Super+←/→/↑/↓` | Focus left/right/up/down |
| `Super+Shift+←/→/↑/↓` | Move window left/right/up/down |
| `Super+LMB` / `Super+RMB` | Move / resize window (drag) |
| `Super+Scroll` | Next / previous workspace |
| `Super+1…6` | Workspace 1–6 (`Super+Shift+1…6` moves the window there) |
| `Ctrl+1…4` | Workspace 7–10, second monitor (`Ctrl+Shift+1…4` moves the window there) |
| `Ctrl+Alt+S` / `V` / `A` | Spotify / Vesktop / Signal, pinned to the second monitor |
| Volume/brightness/media keys | Standard `XF86Audio*` / `XF86Mon*` bindings |

The Claude panel has no bind of its own — open it from its pill, or bind
`qs ipc -c rd-shell call claude toggle` yourself. Every bind above lives in
the compositor (`hypr/hyprland.lua`), not in the bar.

## Theming / dynamic colour

Edit `Config/Colors.qml` — everything reads from it and hot-reloads on save.
The static palette is derived from the
[system24](https://github.com/refact0r/system24) *caelus* theme, accent
`#b86e38`. `templateColor1`…`templateColor12` hold the rest of the caelus
palette, unassigned and ready to name as new widgets need them.

The bar follows the wallpaper **by default**: every switch runs matugen and
`Config/Colors.qml` reads its palette instead of the fixed caelus theme. The
switch lives in `settings.json` next to `shell.qml` (written by
`Services/Settings.qml`, never committed, defaults to `true`):

```json
{ "dynamicColour": false }
```

Set it to `false` for the static caelus palette, `true` or no file at all
for dynamic colour. There is no toggle for it in the settings popup anymore
— colour simply follows the wallpaper unless you edit this file by hand. The
change applies live: `Services/Settings.qml` watches the file and re-runs
the colour pass; wallpaper switches are live too, through `FileView`.

One switch, three surfaces: the bar, the semantic pills and Hyprland's window
borders all read `dynamicColour`. `scripts/wallpaper-apply.sh` applies the
border through `hyprctl eval` (a Lua config refuses `hyprctl keyword`), so
a fresh Hyprland start is already the static look — borders follow on the
next wallpaper change or login, not the instant the switch is flipped.

What follows the wallpaper and what does not:

| | dynamic mode |
|---|---|
| surfaces, accent, label text, island edge, network/keyboard/media/notification pills | matugen roles outright |
| volume (green), mic and power (red), `ok`/`warn`/`error`, the 12 chart slots | hue kept, saturation/brightness borrowed (`Wal.reshade()`) |

Dynamic mode runs on matugen through `Config/Wal.qml`: every switch renders
`matugen/colors.json` into `~/.cache/rd-shell/matugen.json`, and the bar
follows without a restart. If matugen is missing or hasn't rendered yet, the
switch stays inert and the caelus palette holds.

### Firefox

The wallpaper reaches Firefox too. `firefox/userChrome.css` themes the
toolbar and tabs; `firefox/userContent.css` themes `about:blank`/newtab/home
plus the Sidebery and Stylus extension pages (`@-moz-document
moz-extension://<uuid>`). Both `@import "matugen.css"`, which resolves to
`~/.cache/rd-shell/firefox-colors.css` — rendered by matugen's
`[templates.firefox]` from `dotfiles/matugen/templates/firefox-colors.css`
on every wallpaper switch, same as the rest of the rice. Firefox itself only
picks up the new colours on its *next* start: chrome/content CSS is parsed
once, at window creation.

`install.sh`'s Firefox step (skipped if Firefox isn't installed) links the
profile's `chrome/rd-shell` to the repo's `firefox/` and `chrome/matugen.css`
to the rendered colours file, writes two-line `chrome/userChrome.css` and
`chrome/userContent.css` stubs that import both (real files, not links:
Firefox won't follow an `@import` out of a symlinked sheet), and sets
`user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true)` in
`user.js` so Firefox actually loads them.

Two pastes are one-time and not wired by the installer, since both live
inside settings the browser itself owns:

- `firefox/sidebery.css` → Sidebery's own Settings → Styles box
- `firefox/stylus-global.user.css` → a new global style in Stylus

Both read the same `--mg-*` vars `userContent.css` imports, so they follow
the wallpaper too, without ever being re-pasted.

The Sidebery/Stylus blocks in `firefox/userContent.css` key off the
extensions' UUIDs, which are random per Firefox profile — swap in your own
from `about:debugging#/runtime/this-firefox` before those two blocks match
anything.

## Repo layout

```
rd-shell/
├── shell.qml            # entry point: one Bar per screen, IPC handlers
├── Bar*.qml             # the bar — pill order, panel loaders
├── EdgeBar.qml          # per-monitor hover strip, DDC brightness/contrast
├── Launcher.qml         # shell-native app launcher (Super+Space)
├── KeybindOverview.qml  # searchable bind list (Super+K)
├── WallpaperSwitcher.qml# coverflow over ~/Pictures/wall (Ctrl+Alt+F)
├── Claude*.qml          # Claude pill panel: sessions, usage, stats, optimize
├── Sys*.qml             # system monitor pill and its tabbed panel
├── Notification*.qml    # popups, history centre, bell
├── Config/              # Colors.qml (static palette), Wal.qml (matugen)
├── Services/            # singletons: Audio, Network, Ddc, Claude*, Wallpapers, …
├── scripts/             # scripts the services poll or binds call — shell,
│                        # plus sysmon.py, the system monitor's Python sampler
├── assets/fonts/        # caelusevka (bundled) + its OFL licence
├── assets/fontconfig/   # keeps the icon family resolving to the full font
├── hypr/                # the author's Hyprland config, mirrored 1:1
├── dotfiles/             # matugen + app templates (btop, cava, yazi, nvim, …)
├── firefox/             # userChrome/userContent CSS + Sidebery/Stylus pastes
├── wallpapers/          # the author's own additions to LainOS-wallpapers
├── install.sh           # one-time setup
└── launch.sh            # autostart entry — brings audio up, then execs qs
```

**What `install.sh` links where:**

- the whole repo → `~/.config/quickshell/rd-shell` (Quickshell addresses
  configs by directory name, so this exact path matters)
- `hypr/{hyprland.lua,hyprland-gui.lua,hypridle.conf,hyprlock.conf}` →
  `~/.config/hypr/`, individually — not the whole directory, which also
  holds HyprMod's state and generated lock colours
- `hypr/dotfiles/ghostty` → `~/.config/ghostty`, `hypr/dotfiles/rofi` →
  `~/.config/rofi` — whole-directory symlinks, since that's where those two
  configs sit on the source machine
- `scripts/{keybinds,mic-toggle,screenshot}.sh` → `~/.config/hypr/scripts/`,
  the path Hyprland calls them by; the repo owns the real files
- every file under `dotfiles/` → the matching `~/.config/<app>` path —
  matugen's config plus per-app templates (btop, cava, yazi, nvim, vesktop,
  spicetify, fetchit). matugen aborts its whole run if any `input_path` it
  lists is missing, so all of them ship even for apps you don't have

Never committed: matugen's rendered *output* (`~/.config/btop/themes`,
`cava/config`, `nvim/colors/matugen.lua`, etc.) — regenerated on first render.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Every icon is a box | Material Symbols Rounded not installed | re-run `install.sh`, or check `fc-match -f '%{family}' 'Material Symbols Rounded'` |
| Icons render as their own name (`queue_music`, …) | another app's font subset wins the family lookup | `install.sh` links `assets/fontconfig/99-rd-shell-symbols.conf` to drop subsets |
| Text looks like the wrong font | caelusevka not installed | re-run `install.sh`; it copies from `assets/fonts/` |
| Volume shows 0%, no mic pill | started `qs` directly instead of `launch.sh` | kill the shell, use `launch.sh`; check `$XDG_RUNTIME_DIR/rd-shell.log` |
| No notifications at all | swaync/dunst/mako still owns the D-Bus name | `install.sh` masks all three — check none re-enabled itself |
| No audio, PipeWire keeps failing | Iriun's PipeWire drop-in aborts the whole context | `install.sh` patches `iriunaudio.conf` if present |
| Claude panel is empty | no `claude` CLI, or nothing in `~/.claude` | install `claude` yourself — `install.sh` deliberately doesn't |
| Graphics tab shows only the Radeon card | no `libnvidia-ml.so.1` (NVIDIA driver not installed) | expected; the NVIDIA card's rows stay hidden without it |
| Network card reads `--` right after opening | a byte counter needs a predecessor before it's a speed | expected, fills in next sample |
| Edited QML, nothing changed | old `qs` process still running | restart with `launch.sh` |
| Firefox colours didn't change | chrome/content CSS loads once, at startup | restart Firefox |
| System popup stays empty | `python3` missing, or the sampler crashed | install `python3`; check `qs log` |

## Where state lives / uninstall

```
~/.config/quickshell/rd-shell         -> this repo
~/.config/hypr/scripts/*.sh           -> scripts/{keybinds,mic-toggle,screenshot}.sh
~/.config/ghostty, ~/.config/rofi     -> hypr/dotfiles/{ghostty,rofi}
$XDG_RUNTIME_DIR/rd-shell.log         -- shell's own log
~/.cache/qs-bar/                      -- claude-global.sh's transcript cache
~/.cache/rd-shell/                    -- rendered matugen colours, incl. firefox-colors.css
<firefox profile>/chrome/rd-shell, matugen.css
                                       -> firefox/, the cache file above
<firefox profile>/chrome/userChrome.css, userContent.css
                                       -- import stubs written by install.sh
<firefox profile>/user.js             -- adds the legacyUserProfileCustomizations pref
```

To uninstall: remove the autostart line from your Hyprland config, remove
the symlinks above, then unmask whichever notification daemon you want
(`systemctl --user unmask swaync.service` etc — `install.sh` masks all
three, not just the one you use).

## Credits & licences

rd shell's own code and configs are MIT licensed (`LICENSE`). Everything
below keeps its own licence.

- Built with [Quickshell](https://quickshell.outfoxxed.me)
- **caelusevka** — custom [Iosevka](https://github.com/be5invis/Iosevka)
  build, bundled under `assets/fonts/`; SIL OFL 1.1 (`assets/fonts/OFL.txt`)
- **Material Symbols Rounded** — downloaded by `install.sh` from
  [google/material-design-icons](https://github.com/google/material-design-icons),
  Apache 2.0
- **Wallpapers** — cloned from
  [The-LainOS-Project/LainOS-wallpapers](https://github.com/The-LainOS-Project/LainOS-wallpapers);
  the extras in `wallpapers/` belong to their original artists and are not
  covered by the MIT licence
- **fetchit** — [codeberg.org/nzuum/fetchit](https://codeberg.org/nzuum/fetchit)
- **matugen** — [InioX/matugen](https://github.com/InioX/matugen), the
  dynamic-colour pipeline; palette base from
  [system24](https://github.com/refact0r/system24)'s *caelus* theme

---

<div align="center">
<sub>MIT licensed · built with Quickshell</sub>
</div>
