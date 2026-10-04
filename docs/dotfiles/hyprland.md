# Hyprland

`hypr/` is this machine's real `~/.config/hypr`, mirrored 1:1, for the
Lua-configured fork of Hyprland this rice runs on. `install.sh` links five
files from it — not the whole directory, which also accumulates HyprMod state
and generated lock colours that aren't this repo's to own:

| File | Purpose |
|---|---|
| `hyprland.lua` | Main config — monitors, workspaces, binds (see [Keybinds](../keybinds.md)), window rules, autostart, the caelus border colours and the soft inner glow along each window's edge (`decoration.glow`, accent on the focused window, faint grey elsewhere). |
| `hyprland-gui.lua` | HyprMod-generated, loaded *after* `hyprland.lua` — overrides rounding, gaps and cursor theme/size from whatever HyprMod's own GUI last wrote. |
| `animation-presets.lua` | Four named sets of curves and `hl.animation()` calls (Snappy/Smooth/Bouncy/Minimal) — see below. |
| `hypridle.conf` | Locks the session after 5 minutes, blanks displays after 10. Inert unless `hypridle.service` is enabled (`install.sh` offers to). |
| `hyprlock.conf` | Lock-screen layout; sources the seven colour variables `scripts/wallpaper-apply.sh` writes to `hyprlock-colors.conf` on every wallpaper switch. |

## animation-presets.lua

What used to be one inline block of `hl.curve()`/`hl.animation()` calls in
`hyprland.lua` is now four named presets in `animation-presets.lua`, picked
in the shell's own `Ctrl+Alt+P` switcher or its Accessibility-page "Animation"
card (see [Settings](../the-shell/settings.md#accessibility-page)):

- **Snappy** — the same curves as Smooth, speeds roughly 1.6–1.8× higher.
- **Smooth** — the default, and a byte-for-byte match for this rice's
  original hand-tuned curves and speeds.
- **Bouncy** — an overshoot bezier on windows/layers/workspaces (`popin 80%`
  on windows-in).
- **Minimal** — the reduced-motion option: every slide/pop/zoom disabled,
  fades only.

`hyprland.lua` reads the active choice itself, at config-load time, straight
out of `~/.config/quickshell/rd-shell/settings.json` (`io.open` + a Lua
pattern match, no JSON library needed for one key) and calls
`require("animation-presets").apply(name)` — falling back to `"smooth"` if
the file or key is missing. This has to happen in `hyprland.lua` rather than
the shell re-asserting it on its own startup: `hyprctl reload` gives
Hyprland's Lua a **fresh interpreter state** (confirmed empirically — a
global set via a live `hyprctl eval` does not survive a reload), so anything
set only by a one-off shell-side `hyprctl eval` at shell startup would be
silently undone by the next plain `hyprctl reload` (a monitor hotplug, a
`keybind-overrides.lua` save, …). Reading the persisted choice back in
`hyprland.lua` itself means every reload re-applies the right preset,
automatically, with no shell involvement.

Switching presets live (no reload) is the same one-liner,
`hyprctl eval 'require("animation-presets").apply("<name>")'`, run from
`Services/AnimPresets.qml` via `Quickshell.execDetached` — never
`hyprctl keyword`, which can't call into Lua. `require()`'s normal caching
means this is cheap to call repeatedly within one Hyprland session; it's only
a `hyprctl reload` that resets it, which is exactly the case the
`hyprland.lua`-side read above exists to handle.

One caveat, inherent to Hyprland and not fixable short of a full restart:
custom bezier curves registered via `hl.curve()` (Bouncy's `overshoot`) live
in a separate, additive registry that `hyprctl reload` does **not** clear —
unlike every `hl.animation()` leaf setting (speed/curve/enabled/style), which
reloads back to exactly what the active preset specifies. Trying a curve that
defines a new bezier leaves that one definition registered for the rest of
the session; it's inert once you're off that preset, just not removable
without restarting Hyprland outright.

## Autostart

`hyprland.lua`'s `exec-once` block brings up, in order: the wallpaper restore
(`wallpaper-apply.sh --restore`), Vesktop, flatpak Spotify, flatpak Signal (all
three only if installed — nothing here installs them), a `tuned-adm` profile,
`wayvibes` (if built, with a soundpack path that's specific to this machine),
`launch.sh` (which brings the audio graph up before `qs` itself — see
[Fresh install](../installation/fresh-install.md)), the cursor theme, a
polkit authentication agent (below), and a `hyprpm reload -n` to load the
`hyprexpo` plugin into the running session.

## Polkit agent

`/usr/libexec/kf6/polkit-kde-authentication-agent-1` is started explicitly
from `exec-once` — nothing else registers as this session's polkit
authentication agent under Hyprland (its own `.desktop` autostart entry is
KDE-only, and `polkitd` on its own only brokers permission, it never draws a
dialog), so without this line every `pkexec`/GUI-admin prompt hangs or fails
silently. It reads `QT_QPA_PLATFORMTHEME=kde`, so its dialog already follows
the matugen-driven KDE colour scheme.

## Session-lock restore

`misc.allow_session_lock_restore = true` lets `hyprlock` take over a session
another lock client already holds — the fallback `scripts/lock.sh` (see
[Lock screen](../the-shell/lock-screen.md)) depends on this to hand off from
the shell's own lock to `hyprlock` if the former dies.

## Keybind overrides loader

`pcall(dofile, os.getenv("HOME") .. "/.config/hypr/keybind-overrides.lua")`
near the end of the file loads whatever `Super+K`'s in-shell keybind editor
has written — see [Keybinds → Rebinding](../keybinds.md#rebinding). Wrapped
in `pcall` so a missing or broken overrides file never breaks the rest of
`hyprland.lua`.

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
