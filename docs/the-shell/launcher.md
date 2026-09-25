# Launcher & overview

## App launcher (`Launcher.qml`)

Shell-native, search-as-you-type app launcher. `Super+Space`.

## hyprlauncher

A second, independent launcher, external to the shell. `Super+R`. Installed
by `install.sh` (`hyprlauncher` package, from the `lionheartp/Hyprland` COPR).

## Keybind overview (`KeybindOverview.qml`)

`Super+K` opens a searchable list of every Hyprland bind — type to filter,
`Enter` or a click runs the selected one. It's populated live from
`hyprctl binds` (via `scripts/keybinds.sh` and `Services/Keybinds.qml`), not
from parsing `hyprland.lua`, so it always matches what's actually bound in the
running session, including the generated per-workspace binds. See
[Keybinds](../keybinds.md) for the full table.

## Wallpaper switcher (`WallpaperSwitcher.qml`)

`Ctrl+Alt+F` opens a fullscreen coverflow over `~/Pictures/wall`. Picking a
wallpaper re-renders matugen and the bar, Hyprland's window borders and the
rest of the rice follow — no restart. See
[Wallpaper switcher](../theming/wallpaper-switcher.md).

## Workspace overview

`` Super+` `` opens Hyprland's `hyprexpo` plugin (added and enabled by
`install.sh`), a grid overview of every workspace.
