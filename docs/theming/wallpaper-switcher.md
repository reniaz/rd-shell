# Wallpaper switcher

`Ctrl+Alt+F` opens `WallpaperSwitcher.qml`, a fullscreen coverflow over
`~/Pictures/wall`. Picking an image hands it to `scripts/wallpaper-apply.sh`,
which is the one place the actual switch logic lives — the same script runs
on Hyprland's own startup (`--restore`) and on every switch from the UI, so
a fresh login gets exactly what a manual switch would produce.

## `scripts/wallpaper-apply.sh`

```
wallpaper-apply.sh <abs image path>   # from the switcher overlay
wallpaper-apply.sh --restore          # from Hyprland's own startup
wallpaper-apply.sh --border           # re-apply just the window borders
wallpaper-apply.sh --lock             # re-render just the lock-screen palette
```

In order, a normal call:

1. Kills any stray `swaybg` process left over from before Quickshell owned
   the desktop background layer.
2. Resolves the scheme/mode with `scripts/matugen-scheme.sh` (reads
   `Config/Caelus.qml`'s `scheme`/`colorMode`, falling back to
   `tonal-spot`/`dark`).
3. Runs matugen twice — see [The matugen pipeline](matugen-pipeline.md) for
   what each run renders.
4. `apply_border` — pushes the new window-border colours into the running
   Hyprland with `hyprctl eval` (a Lua config can't be re-keyworded).
5. `apply_lock` — writes `~/.config/hypr/hyprlock-colors.conf`, which
   `hyprlock.conf` sources.
6. Writes the chosen image's path to `~/.cache/rd-shell/wallpaper` — the
   state file `Services/Wallpapers.qml`'s `FileView` watches. This write is
   what actually starts Quickshell's desktop crossfade (`Wallpaper.qml`), so
   it's deliberately the last step that can affect the bar.
7. Re-encodes the image to `~/.cache/rd-shell/lock.png` (first frame only,
   downscaled to at most 2560×1440) for the lock screen, and — if the
   one-time root setup described in the install summary was done — publishes
   it to `/usr/share/backgrounds/rd-shell/current.png` for the login
   screen too.

`--border` and `--lock` exist because `hyprctl reload` re-reads
`hyprland.lua`'s literal border colours and would otherwise silently undo a
dynamic border on every reload (by `hyprpm`, a keybind, or a config edit) —
`hyprland.lua` runs `wallpaper-apply.sh --border` on every `exec` (not
`exec-once`) reload to keep it in sync without paying for a full matugen
render.

## The preview

`scripts/wallpaper-scan.sh` lists the candidates the coverflow shows;
`scripts/wallpaper-preview.sh` renders a throwaway matugen pass per swatch,
using the exact same scheme/mode resolution as the real apply
(`scripts/matugen-scheme.sh`) — a preview computed a different way than the
apply would produce mismatched colours, which is worse than no preview.

## Adding wallpapers

Drop images into `~/Pictures/wall` (or, for something that should ship with
the repo itself, into `wallpapers/` — `install.sh` copies it into
`~/Pictures/wall` on every run, without overwriting anything already there).
`install.sh` also offers to clone
[LainOS-wallpapers](https://github.com/The-LainOS-Project/LainOS-wallpapers)
as the default set.
