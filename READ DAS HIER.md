# READ DAS HIER

Read this before you run anything. It tells you what this config actually is,
what `install.sh` does to your machine, and what to check when a pill is blank
or a bind does nothing.

## 1. What this is

`rd-shell` is a [Quickshell](https://quickshell.outfoxxed.me) bar config. The
directory name matters: Quickshell addresses configs by directory name, so
every `qs -c rd-shell` and `qs ipc -c rd-shell` in this doc (and in the scripts)
depends on the repo being symlinked to exactly `~/.config/quickshell/rd-shell`.

30-second version:

```bash
git clone <this repo> ~/coding/qs-bar   # or wherever you keep it
cd ~/coding/qs-bar
./install.sh
```

Then add the autostart line from §3 to your Hyprland config and log back in
(or run `~/.config/quickshell/rd-shell/launch.sh` by hand to try it without
restarting the session).

Do **not** start the bar with `qs -c rd-shell` directly, and do not put that in
your autostart. Always go through `launch.sh`. It repairs and waits for the
PipeWire graph before starting Quickshell — start `qs` cold and the shell reads
an empty audio graph, and you get 0% volume and no mic for the rest of the
session. `launch.sh` also pgrep-kills any previous `qs -c rd-shell` instance
before starting a new one, so it's what you re-run after editing QML too.

## 2. Prerequisites

- Fedora 44. `install.sh` uses `dnf5` and `dnf5 copr enable`; other distros are
  not supported by the script (the QML itself has no Fedora-specific code).
- Wayland, Hyprland — **already installed and configured by you**. `install.sh`
  never installs or touches your compositor; it only sets up the bar and the
  handful of binaries the bar shells out to (`hyprlock` and `hyprshutdown` for
  the power menu, and it enables the Hyprland COPR only if those two are
  missing). Niri is untested on this machine — nothing here reads
  Hyprland-specific state except the workspace dots, `KeyboardLayout.qml`
  (`hyprctl switchxkblayout`) and the power/lock binds, so niri may work for
  everything else, but nobody has checked.
- A **second keyboard layout**. The layout pill and its OSD only render when
  Hyprland's `kb_layout` lists more than one layout — see §3. With a single
  layout there is nothing for the pill to show and it stays hidden.
- NVIDIA is optional. Without a card, or without `nvidia-smi`/`nvidia-settings`,
  the GPU-busy figure is deliberately left blank rather than guessed at.

## 3. Hyprland setup

This machine runs Hyprland's Lua config (`~/.config/hypr/hyprland.lua`,
`hl.*` API), not `hyprland.conf`. Both are given below — use whichever your
Hyprland setup actually reads.

### hyprland.lua

```lua
-- autostart
hl.exec_cmd("~/.config/quickshell/rd-shell/launch.sh")

hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("qs ipc -c rd-shell call power toggle"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("qs ipc -c rd-shell call notifications toggle"))

hl.bind("CTRL + SHIFT + M", hl.dsp.exec_cmd("~/.config/hypr/scripts/mic-toggle.sh"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("~/.config/hypr/scripts/mic-toggle.sh"),
        { locked = true, repeating = true })

-- drives the keyboard-layout pill + its OSD
hl.bind("CTRL + SHIFT + SPACE", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))

hl.bind("CTRL + ALT + up", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh area"))

-- inside the hl.config({ ... }) call that holds your input settings
input = {
    kb_layout = "us,de",   -- two layouts, otherwise the layout pill has nothing to show
},
```

### hyprland.conf equivalent

```ini
exec-once = ~/.config/quickshell/rd-shell/launch.sh

bind = $mainMod, M, exec, qs ipc -c rd-shell call power toggle
bind = $mainMod, L, exec, hyprlock
bind = $mainMod, N, exec, qs ipc -c rd-shell call notifications toggle

bind = CTRL SHIFT, M, exec, ~/.config/hypr/scripts/mic-toggle.sh
bindl = , XF86AudioMicMute, exec, ~/.config/hypr/scripts/mic-toggle.sh

# drives the keyboard-layout pill + its OSD
bind = CTRL SHIFT, SPACE, exec, hyprctl switchxkblayout all next

bind = CTRL ALT, up, exec, ~/.config/hypr/scripts/screenshot.sh area

input {
    kb_layout = us,de
    kb_variant =
    kb_options =
}
```

What each bind is for:

| Bind | Does |
|---|---|
| `Super + M` | Toggle the power menu |
| `Super + L` | `hyprlock` |
| `Super + N` | Toggle the notification center |
| `Ctrl+Shift+M` / `XF86AudioMicMute` | Mute/unmute mic via `mic-toggle.sh`, locked+repeating so it works while held or on a laptop's dedicated key |
| `Ctrl+Shift+Space` | Cycle keyboard layout — this is what the keyboard pill and its OSD react to |
| `Ctrl+Alt+Up` | Area screenshot via `screenshot.sh`, copies to clipboard |

**Super+C is not bound on this machine**, even though older docs in this repo
claim it opens the Claude panel. The Claude and system panels have no bind of
their own — open them by clicking their pill, or bind
`qs ipc -c rd-shell call claude toggle` / `qs ipc -c rd-shell call system toggle`
yourself if you want a key for them. The full set of IPC targets `shell.qml`
exports:

| Target.function | Does |
|---|---|
| `power.toggle` | Power menu |
| `notifications.toggle` | Notification center |
| `notifications.dnd` | Toggle do-not-disturb |
| `system.toggle` | System monitor panel |
| `claude.toggle` | Claude panel |

Other lines around line 60-64 of `hyprland.lua` on this machine (vesktop,
swaybg wallpaper, `tuned-adm`, wayvibes, `hyprctl setcursor`) are this
machine's personal autostart, unrelated to the bar — you don't need any of
them.

## 4. Tour of the bar

Left to right, as laid out in `Bar.qml`:

**Left** — workspace dots (scroll to switch), the media pill (what is playing),
then the system readout (CPU / GPU / RAM), which sits beside the media pill
rather than in the right-hand cluster.

**Centre** — clock. Click to expand it to `time | date`.

**Right** — Claude pill (usage %), keyboard layout, disk, tray icons, mic,
volume, network, notification bell, power.

Every panel hangs from its pill via the shared `BarPopup` component and opens
on click unless noted:

| Pill | Opens with | Notes |
|---|---|---|
| System readout | left-click | tabs: Processor, Graphics, Memory; can SIGTERM/SIGKILL a process from the process lists |
| Claude | left-click | tabs: Sessions, Usage, Statistics, Optimize |
| Disk | left-click | refreshes on open |
| Mic | left-click toggles mute, right-click opens `pavucontrol -t 4`, scroll adjusts volume |
| Volume | left-click toggles mute, right-click opens `pavucontrol -t 3`, scroll adjusts volume |
| Network | right-click only, opens `kcmshell6` to the NetworkManager KCM |
| Notification bell | left-click opens the notification center, right-click toggles DND |
| Power | left-click | lock / logout / reboot / shutdown via `hyprlock` / `hyprshutdown` |

## 5. What shells out to what

The Claude panel and system monitor never start a `claude` process to answer a
question — the four tabs and the readout pill are all driven by shell scripts
that read state on disk:

| Script | Reads | Costs |
|---|---|---|
| `scripts/claude-status.sh` | `~/.claude` state files | ~40ms, polled every 2s |
| `scripts/claude-session.sh` | one whole transcript | ~0.2s, only while a row is open |
| `scripts/claude-global.sh` | every transcript ever written | ~3.4s cold, ~0.1s warm (cached per file on `(mtime, size)` in `~/.cache/qs-bar/`) |
| `scripts/claude-usage.sh` | the `/usage` endpoint | one request per minute |
| `scripts/sysmon.sh` | `/proc`, hwmon, `nvidia-settings` | ~80ms, polled every 2s |
| `scripts/sysmon-procs.sh` | two `top` passes 0.2s apart | ~0.5s, only while the panel is open |

Other scripts, bound from Hyprland rather than polled:

| Script | Runs when |
|---|---|
| `scripts/mic-toggle.sh` | mic pill click, `Ctrl+Shift+M`, `XF86AudioMicMute` |
| `scripts/screenshot.sh` | `Ctrl+Alt+Up` (area capture, copies to clipboard) |

Everything above needs its command on `PATH`; `install.sh` checks each one and
tells you which package provides it. `hyprctl` is used by the workspace dots,
`KeyboardLayout.qml` and `claude-status.sh` (to find the focused window);
`nmcli` and `kcmshell6` by the network pill; `wpctl` by the mic script and
Hyprland's own volume binds; `jq` and `gawk` by every `claude-*.sh`; `top` and
`free` by the process lists; `curl` by `claude-usage.sh`; `grim`/`slurp`/
`wl-copy` by the screenshot script.

## 6. Theming

Everything reads from `Config/Colors.qml` and hot-reloads the moment you save
it — no restart needed for a colour change. `Config/Format.qml` holds the
shared number formatting (byte sizes, durations) so a popup doesn't disagree
with itself about whether 9.4G rounds to 9G.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Every icon is a box | Material Symbols Rounded not installed | re-run `install.sh`, or check `fc-match -f '%{family}' 'Material Symbols Rounded'` |
| Text looks like the wrong font | caelusevka not installed | re-run `install.sh`; it copies from `assets/fonts/` — if that directory is missing, text falls back to the system sans |
| Volume shows 0%, no mic pill | started `qs` directly instead of `launch.sh` | kill the shell, start it with `launch.sh`; check `$XDG_RUNTIME_DIR/rd-shell.log` |
| No notifications at all | swaync / dunst / mako still owns the `org.freedesktop.Notifications` D-Bus name | `install.sh` masks all three with `systemctl --user mask`; check none of them re-enabled itself |
| No audio anywhere, PipeWire keeps failing | Iriun's PipeWire drop-in aborts the whole PipeWire context on some machines | `install.sh` patches `/usr/share/pipewire/pipewire.conf.d/iriunaudio.conf` if present — only relevant if you have Iriun installed |
| Claude panel is empty | no Claude CLI, or nothing in `~/.claude` | install `claude` yourself; `install.sh` deliberately does not do this for you |
| GPU-busy figure is blank | no `nvidia-smi` on this machine (needs `cuda-devel`, not installed by default) | expected, not a bug — VRAM/temp/fan still come from `nvidia-settings` |
| Edited a QML file, nothing changed | Quickshell only reloads on a real content change, and you're still running the old process | restart with `launch.sh` — it kills the previous instance with `pgrep -fx "qs -c rd-shell"`, anchored to the whole command line so an editor that merely has the string open survives |

## 8. Where state lives, and how to remove this

```
~/.config/quickshell/rd-shell         -> this repo
~/.config/hypr/scripts/mic-toggle.sh  -> scripts/mic-toggle.sh
~/.config/hypr/scripts/screenshot.sh  -> scripts/screenshot.sh
$XDG_RUNTIME_DIR/rd-shell.log         -- shell's own log
~/.cache/qs-bar/                      -- claude-global.sh's per-file transcript cache
```

To uninstall: remove the autostart line from your Hyprland config, remove the
two `~/.config/hypr/scripts/*.sh` symlinks and the `~/.config/quickshell/rd-shell`
symlink, then unmask whichever notification daemon you actually want running
again (`systemctl --user unmask swaync.service` etc — `install.sh` masked
swaync, dunst and mako, not just the one you use).
