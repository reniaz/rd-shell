# The matugen pipeline

Every wallpaper switch runs `scripts/wallpaper-apply.sh`, which calls
[matugen](https://github.com/InioX/matugen) twice against the chosen image
(`--prefer saturation`, a fixed scheme/mode resolved by
`scripts/matugen-scheme.sh`):

1. **`matugen/bar.toml`** first — renders only the bar's own template
   (`Config/Wal.qml` reads the result). Kept as a separate, first run so no
   app template further down the pipeline can ever stop the bar from
   following the wallpaper if it fails.
2. **`dotfiles/matugen/config.toml`** second — every app template. matugen
   aborts its *entire* run on the first `input_path` it can't find, so every
   template ships in `dotfiles/` even for apps you don't have installed.

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

## Why two matugen runs, and why non-fatal

- Splitting the bar's render from the apps' means a broken app template never
  leaves the bar on stale colours.
- Both runs swallow matugen failures by design — a bad render must never
  block a wallpaper switch. `wallpaper-apply.sh`'s own output files
  (`matugen.json`, `themes/matugen`, `hyprlock-colors.conf`) are checked
  afterwards instead of matugen's exit status, both by the installer's first
  render step and anyone diagnosing a stale theme.

## Config files

- `dotfiles/matugen/config.toml` — every app template, linked to
  `~/.config/matugen/config.toml` by `install.sh`.
- `matugen/bar.toml` (repo root, not under `dotfiles/`) — the bar-only
  template, run first.
- `dotfiles/matugen/templates/*` — the actual template bodies
  (`gtk-colors.css`, `kde-colors.colors`, `firefox-colors.css`,
  `bat.tmTheme`, `papirus-accent.txt`).
