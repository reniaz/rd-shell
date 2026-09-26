# Keybinds

`Super+K` opens a searchable, in-bar overview of every bind below — type to
filter, `Enter` or a click runs the selected one.

## Source of truth

Every bind lives in `hypr/hyprland.lua`, each with its own `description`
field. `Super+K`'s data does **not** come from parsing that file, though —
`scripts/keybinds.sh` decodes it from `hyprctl binds -j` (the live
compositor's own bind table) at open time, using each bind's `description` to
label rows the Lua-dispatch mechanism (`__lua`) would otherwise show as
meaningless callback IDs. That's read by `Services/Keybinds.qml` and rendered
by `KeybindOverview.qml`. In short: the table below and the live overview
both describe the same source, `hypr/hyprland.lua`, and should always match —
if they don't, `hyprland.lua` won a `git pull` since the last time this table
was checked.

`mainMod` is `SUPER` throughout. Two named outputs (`MAIN`/`SECOND` in
`hyprland.lua`) split workspaces 1–6 and 7–10 across two monitors — see
[Fresh install](installation/fresh-install.md) for setting those to your own
monitor names.

## Rebinding

The Edit toggle in `Super+K`'s own overview (`KeybindOverview.qml`) lets you
capture a new chord for any bind with a ref and write it, live, with no
manual editing of `hyprland.lua`. While it's capturing, Hyprland's own
shortcuts are paused, so a chord already bound to something else (e.g.
`Super+S`, the sticky note key) can still be captured instead of vanishing
into the compositor before the overview ever sees it. A clash with an
existing bind shows "Already used by …" before you save, and Save replaces
it anyway; `Esc` cancels the capture (and un-pauses shortcuts) without
writing anything. Overrides are written to
`~/.config/hypr/keybind-overrides.lua`, loaded by `hyprland.lua` itself
(`pcall(dofile, ...)` near the end of the file, so a missing or broken
overrides file never breaks the rest of the config) — `Services/Keybinds.qml`
does the write, reload and rollback (`hyprctl reload` +
`hyprctl configerrors`) round trip. "Reset to defaults" in the same panel
deletes that file and reloads.

## Apps & windows

| Combo | Action |
|---|---|
| `Super+Q` | Terminal (ghostty) |
| `Super+W` | Close window |
| `Super+E` | File manager (dolphin) |
| `Super+B` | Browser (firefox) |
| `Super+Space` | App launcher (shell-native) |
| `Super+R` | Launcher (hyprlauncher) |
| `Super+K` | Keybind overview (search) |
| `Super+V` | Float / tile window |
| `Super+P` | Pseudotile window |
| `Super+F` | Fullscreen window |
| `Super+Shift+F` | Fake fullscreen (keeps the bar) |
| `Super+J` | Toggle split direction |

## Focus & move

| Combo | Action |
|---|---|
| `Super+←/→/↑/↓` | Focus left/right/up/down |
| `Super+Shift+←/→/↑/↓` | Move window left/right/up/down |
| `Super+LMB` (drag) | Move window |
| `Super+RMB` (drag) | Resize window |
| `Super+Scroll down` | Next workspace |
| `Super+Scroll up` | Previous workspace |

## Workspaces

| Combo | Action |
|---|---|
| `Super+1…6` | Focus workspace 1–6 (main monitor) |
| `Super+Shift+1…6` | Move window to workspace 1–6 |
| `Ctrl+1…4` | Focus workspace 7–10 (second monitor) |
| `Ctrl+Shift+1…4` | Move window to workspace 7–10 |
| `` Super+` `` | Workspace overview (hyprexpo) |
| `Ctrl+Alt+S` | Spotify, pinned to a workspace on the second monitor |
| `Ctrl+Alt+V` | Vesktop, pinned to a workspace on the second monitor |
| `Ctrl+Alt+A` | Signal, pinned to a workspace on the second monitor |

## Shell

| Combo | Action |
|---|---|
| `Ctrl+Alt+F` | Wallpaper switcher |
| `Ctrl+Shift+Escape` | System monitor |
| `Super+N` | Notification panel |
| `Super+M` | Power menu |
| `Super+L` | Lock the session |
| `Super+S` | New sticky note (empty workspace only) |
| `Ctrl+Alt+↑` | Screenshot a region |
| `Ctrl+Alt+↓` | Screenshot a region, then annotate it in swappy |

The Claude panel has no bind of its own — open it from its pill, or bind
`qs ipc -c rd-shell call claude toggle` yourself.

## Audio, mic & brightness

| Combo | Action |
|---|---|
| `Ctrl+Shift+M` / `Mic Mute` | Mute / unmute the microphone |
| `Ctrl+Shift+Space` | Cycle the keyboard layout |
| `Audio Raise Volume` | Volume up |
| `Audio Lower Volume` | Volume down |
| `Audio Mute` | Mute / unmute |
| `Mon Brightness Up` | Brightness up |
| `Mon Brightness Down` | Brightness down |
| `Audio Next` | Next track |
| `Audio Play` / `Audio Pause` | Play / pause |
| `Audio Prev` | Previous track |

These are the standard `XF86Audio*`/`XF86Mon*` media keys — `Super+K` shows
them with the `XF86` prefix stripped and spaced (e.g. `Audio Raise Volume`).
