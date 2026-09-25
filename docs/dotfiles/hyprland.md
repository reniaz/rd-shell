# Hyprland

`hypr/` is this machine's real `~/.config/hypr`, mirrored 1:1, for the
Lua-configured fork of Hyprland this rice runs on. `install.sh` links four
files from it — not the whole directory, which also accumulates HyprMod state
and generated lock colours that aren't this repo's to own:

| File | Purpose |
|---|---|
| `hyprland.lua` | Main config — monitors, workspaces, binds (see [Keybinds](../keybinds.md)), window rules, autostart, the caelus border colours. |
| `hyprland-gui.lua` | HyprMod-generated, loaded *after* `hyprland.lua` — overrides rounding, gaps and cursor theme/size from whatever HyprMod's own GUI last wrote. |
| `hypridle.conf` | Locks the session after 5 minutes, blanks displays after 10. Inert unless `hypridle.service` is enabled (`install.sh` offers to). |
| `hyprlock.conf` | Lock-screen layout; sources the seven colour variables `scripts/wallpaper-apply.sh` writes to `hyprlock-colors.conf` on every wallpaper switch. |

## Autostart

`hyprland.lua`'s `exec-once` block brings up, in order: the wallpaper restore
(`wallpaper-apply.sh --restore`), Vesktop, flatpak Spotify, flatpak Signal (all
three only if installed — nothing here installs them), a `tuned-adm` profile,
`wayvibes` (if built, with a soundpack path that's specific to this machine),
`launch.sh` (which brings the audio graph up before `qs` itself — see
[Fresh install](../installation/fresh-install.md)), the cursor theme, and a
`hyprpm reload -n` to load the `hyprexpo` plugin into the running session.

## Live wallpaper follow on reload

`hyprctl reload` re-reads `hyprland.lua`'s literal border colours, which would
silently undo a dynamic border on every reload. An `exec` line (not
`exec-once`, so it re-runs on every reload) calls
`scripts/wallpaper-apply.sh --border` to reassert the live colours — see
[The matugen pipeline](../theming/matugen-pipeline.md).

## Machine-specific lines

A handful of lines in `hyprland.lua` are typed out for the machine this rice
was copied from and need editing on any other box — see the checklist in
[Fresh install](../installation/fresh-install.md#after-the-script-finishes):
monitor names and the `MAIN`/`SECOND` output aliases, the NVIDIA
`LIBVA_DRIVER_NAME` env line, and `input.kb_layout`.

## `hyprland.conf` vs `hyprland.lua`

This fork of Hyprland loads `hyprland.lua` **instead of** `hyprland.conf`
whenever `hyprland.lua` exists, from your next full restart — not a plain
`hyprctl reload`. If you already had your own `~/.config/hypr/hyprland.conf`,
`install.sh` backs it up rather than touching it further; see [Installing
over an existing config](../installation/existing-config.md) for exactly
what gets backed up and how to roll back to it.

## hyprexpo plugin

Added and enabled by `install.sh` via `hyprpm` (needs a running Hyprland
session — see [What install.sh does](../installation/what-install-does.md)).
`hyprland.lua` calls it through `hl.plugin.hyprexpo.expo`, guarded so a
session where the plugin failed to load doesn't error on the bind.
