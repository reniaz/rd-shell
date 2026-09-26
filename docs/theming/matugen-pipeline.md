# The matugen pipeline

Every wallpaper switch runs `scripts/wallpaper-apply.sh`, which calls
[matugen](https://github.com/InioX/matugen) three times against the chosen
image (`--prefer saturation`, a scheme/mode resolved by
`scripts/matugen-scheme.sh` — normally `Config/Caelus.qml`'s fixed
`tonal-spot`, or `content` when the settings popup's
[Wallpaper colours](../the-shell/settings.md) toggle is on, or `monochrome`
if that toggle is on and the wallpaper itself is achromatic):

1. **`matugen/bar.toml`** first — renders only the bar's own template
   (`Config/Wal.qml` reads the result). Kept as a separate, first run so no
   app template further down the pipeline can ever stop the bar from
   following the wallpaper if it fails.
2. **`dotfiles/matugen/config.toml`** second — every app template except
   nvim's and bat's own syntax highlighting (see below). matugen aborts its
   *entire* run on the first `input_path` it can't find, so every template
   ships in `dotfiles/` even for apps you don't have installed.
3. **`matugen/hue.toml`** third — just `[templates.nvim]` and
   `[templates.bat]`, with a scheme of their own: normally the same one run
   2 used, but if that resolved to `monochrome` and the settings popup's
   **Keep app colours** toggle is on (the default), these two render with
   the fixed hued scheme instead. See
   [Why a third run](#why-a-third-run-for-just-nvim-and-bat) below.

## What gets rendered

| App | Live, or next launch/restart? |
|---|---|
| Bar | live, no restart |
| ghostty | live (D-Bus reload) |
| Qt/KDE | live (`plasma-apply-colorscheme`) |
| vesktop | live (Vencord watches its themes folder) |
| nvim | live (nvim's own file watcher, not matugen) |
| Spotify (spicetify) | live once running (`theme.js` fetches its accent file at runtime) — see [spicetify](../dotfiles/spicetify.md) for the first-launch/post-update caveats |
| btop | live (`SIGUSR2` reload) |
| cava | live, terminal instance only (the bar's own visualizers use a separate config this pipeline never touches — see [cava](../dotfiles/cava.md)) |
| GTK | next launch |
| Icons (Papirus folders) | next icon lookup |
| `bat` | next invocation |
| yazi | next launch |
| Firefox | next start (chrome CSS parses once) |

Every template's exact `input_path`/`output_path`/`post_hook`, the harmonized
ANSI colours block, and how to add a template for a new app:
**[matugen (config reference)](../dotfiles/matugen.md)**.

Hyprland's window borders and the lock screen aren't matugen templates —
`scripts/wallpaper-apply.sh` writes them directly (`apply_border` via
`hyprctl eval`, `apply_lock` writing `~/.config/hypr/hyprlock-colors.conf`,
which `hyprlock.conf` sources for its seven colour variables). Lock screen
state colours (`$ok`, `$fail`, the auth states) deliberately don't follow the
wallpaper — they mean the same thing at every hour and are read under stress.

## Three runs, not two

- Splitting the bar's render from the rest means a broken app template never
  leaves the bar on stale colours.
- Splitting nvim and bat from the rest of the apps is what lets them render
  with a *different* scheme in the same wallpaper switch: matugen renders an
  entire run with one `--type`/`--mode`, so the only way for two templates
  to end up hued while everything else goes monochrome is to put them in a
  run of their own. `scripts/matugen-scheme.sh --hue` is what decides
  whether that run actually gets a different scheme (see
  [nvim](../dotfiles/nvim.md#matugen-colourscheme) and
  [matugen (config reference)](../dotfiles/matugen.md) for the exact
  mechanics).
- All three runs swallow matugen failures by design — a bad render must
  never block a wallpaper switch. `wallpaper-apply.sh`'s own output files
  (`matugen.json`, `themes/matugen`, `hyprlock-colors.conf`) are checked
  afterwards instead of matugen's exit status, both by the installer's first
  render step and anyone diagnosing a stale theme.

### Why a third run for just nvim and bat

An achromatic wallpaper resolving to `scheme-monochrome` is the right call
for chrome — a grey bar and grey GTK windows matching a grey wallpaper — but
nvim and bat don't have a "surface" to recolour, they have syntax groups
that tell keywords from strings from comments purely by hue. Monochrome
collapses all of that to a handful of greys (verified: a real achromatic
wallpaper's rendered `colors/matugen.lua`, before this pipeline existed,
carried exactly one non-grey family — Material's `error` role, which stays
red-ish in every scheme — everything else was `#000000`…`#ffffff`). The
**Keep app colours** setting exists so that loss is opt-out, not permanent:
on (default), these two templates keep reading the fixed, always-hued
scheme instead. Every other template that also happens to read multiple
hues off these same roles — ghostty's ANSI palette, btop's box outlines,
yazi's file-type badges, starship's per-segment colours — stays in the
second run and goes monochrome with the rest of chrome; only nvim and bat
were carved out.

Swapping the scheme is deliberately only half the fix: nvim and bat also
read `surface`/`on_surface`/`outline`/etc for their own background,
foreground and box edges — the same roles ghostty's `background =
{{colors.surface.default.hex}}` uses — and those roles differ between
chrome's monochrome render and the hue pass's hued one, so rendered as-is
the editor would keep its syntax colours but sit in a visibly different
grey than the terminal around it. `scripts/wallpaper-apply.sh` closes that
gap without touching either template: chrome's own run (otherwise
unchanged) is asked to also dump its computed colours (`-j hex`, which
matugen produces before it renders any template, so this costs no extra
run), a `jq` filter keeps only the neutral roles — background and every
surface/outline/inverse variant, shadow, scrim, deliberately never
primary/secondary/tertiary/error — and `--import-json` hands that back to
the hue pass, which merges it over its own computed roles before rendering.
Only happens when the hue pass's scheme actually differs from chrome's (the
one case this matters); every other run, and a machine without `jq`, renders
exactly as if this didn't exist.

## Config files

- `dotfiles/matugen/config.toml` — every app template except nvim's and
  bat's, linked to `~/.config/matugen/config.toml` by `install.sh`.
- `matugen/bar.toml` (repo root, not under `dotfiles/`) — the bar-only
  template, run first.
- `matugen/hue.toml` (repo root, not under `dotfiles/`) — just
  `[templates.nvim]` and `[templates.bat]`, run third.
- `dotfiles/matugen/templates/*` — the actual template bodies
  (`gtk-colors.css`, `kde-colors.colors`, `firefox-colors.css`,
  `bat.tmTheme`, `papirus-accent.txt`).
