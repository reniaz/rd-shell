# btop

## Notable settings (`dotfiles/btop/btop.conf`)

`dotfiles/btop/btop.conf` is a genericized copy of the author's own
`~/.config/btop/btop.conf` — everything machine-specific (sensor picks, core
mapping) left at auto-detected defaults. The settings worth knowing about:

| Setting | Value | What it does |
|---|---|---|
| `color_theme` | `"matugen"` | resolves to `~/.config/btop/themes/matugen.theme`, the rendered theme file below |
| `theme_background` | `true` | theme's own background colour, not terminal transparency |
| `truecolor` | `true` | 24-bit colour, not the 256-colour fallback |
| `shown_boxes` | `"cpu mem net proc"` | no GPU box in the default layout — GPU stats live in this shell's own [system monitor popup](../the-shell/popups.md) instead |
| `presets` | 3 presets (`cpu:1:default,proc:0:default` / `cpu:0:default,mem:0:default,net:0:default` / `cpu:0:block,net:0:tty`) | cycled with `p`; different box layouts and graph symbols per preset |
| `graph_symbol` | `"braille"` | highest-resolution graphs; per-box overrides (`graph_symbol_cpu` etc.) left at `"default"` |
| `update_ms` | `2000` | 2s sample interval — btop's own recommended minimum for stable graph sample times |
| `rounded_corners` / `terminal_sync` | `true` / `true` | cosmetic box corners; synchronized-output escape sequences to cut flicker on supporting terminals |
| `vim_keys` | `false` | arrow keys, not `hjkl`, for navigation |
| `proc_sorting` | `"cpu lazy"` | top process over time rather than jumping on every sample |

## The matugen wiring

- Template: `dotfiles/btop/matugen/matugen.theme` → `[templates.btop]` in
  `dotfiles/matugen/config.toml` → rendered to
  `~/.config/btop/themes/matugen.theme` on every wallpaper switch.
- Colour roles: Material surfaces/text for the chrome (background, main text,
  titles, meters), the six harmonized custom hues (red/green/yellow/blue/
  magenta/cyan — blended toward the wallpaper, defined once in
  `config.toml`'s `[config.custom_colors]`) for anything that needs to stay a
  visually distinct colour rather than collapse toward monochrome on a
  one-hue tonal-spot wallpaper — box outlines, per-metric graph gradients
  (temperature, CPU load, download/upload, free/used/cached).
- Graph gradients read in the direction their meaning implies: CPU/temp/used
  go green → yellow → red (low is good), free/available go red → yellow →
  green (low is bad), download/upload/cached use distinct neutral hue paths
  with no good/bad direction.
- `post_hook`: `pkill -USR2 -x btop || true` — matches only a process
  literally named `btop`. A running instance re-reads both `btop.conf` and
  the active `.theme` file from disk on that signal, with no restart.
  No-ops quietly if btop isn't running.

## Tweaking it

Edit `dotfiles/btop/matugen/matugen.theme` for colours (re-render with
`scripts/wallpaper-apply.sh --restore`); edit `~/.config/btop/btop.conf`
directly for layout/behaviour settings like the ones in the table above —
btop rewrites this file on its own exit, so hand edits should be made with
btop closed, or expect them to be there again next launch since btop only
ever rewrites the keys it manages, not a wholesale regeneration.

## How it's installed

`btop.conf` rewrites itself on exit, which makes a plain symlink fragile —
edit through the shell, close it, and the process can leave the file in a
state that no longer matches the repo copy. `install.sh`'s "btop theme" step
is a copy, not the usual per-file symlink `dotfiles/` otherwise gets, and it
handles both cases you can land in:

- **You already have a `~/.config/btop/btop.conf`** — left almost entirely
  alone, only patched: if `color_theme` is already `"matugen"`, nothing
  happens; if it's set to something else, the whole file is backed up
  (`btop.conf.bak-YYYYmmdd-HHMMSS`) and just that one line is rewritten with
  `sed`; if btop.conf exists but has no `color_theme` line at all, one is
  appended. Your own layout, sensors and everything else in the file is
  never touched.
- **No `~/.config/btop/btop.conf` yet** — `dotfiles/btop/btop.conf` (the
  full config, `color_theme` already `"matugen"`) is copied in whole as the
  starting point.

See [Installing over an existing config](../installation/existing-config.md)
for how this fits the rest of the backup story.
