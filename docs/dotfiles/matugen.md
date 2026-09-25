# matugen (config reference)

This page is the config reference for [matugen](https://github.com/InioX/matugen)
itself — every template's exact paths and reload command. For the concept
(why two runs, what "dynamic colour" means, which surfaces follow the
wallpaper) see [Theming → The matugen pipeline](../theming/matugen-pipeline.md);
this page doesn't repeat that, only the mechanics.

## Config files

- `matugen/bar.toml` (repo root) — the bar-only config, rendered in a run of
  its own, first. `[templates.rd-shell]` is its only entry.
- `dotfiles/matugen/config.toml` — every app template, linked to
  `~/.config/matugen/config.toml`. Rendered second, once the bar's own run
  has already succeeded or failed on its own.
- `dotfiles/matugen/templates/*` — template bodies for apps that don't keep
  their own `matugen/` subfolder (`gtk-colors.css`, `kde-colors.colors`,
  `firefox-colors.css`, `bat.tmTheme`, `papirus-accent.txt`). Apps with more
  going on keep their template next to their other config instead — see each
  app's own dotfiles page for its actual template path.

## Every `[templates.*]` entry

| Entry | `input_path` → `output_path` | `post_hook` | Reload |
|---|---|---|---|
| `[templates.rd-shell]`¹ | `~/.config/quickshell/rd-shell/matugen/colors.json` → `~/.cache/rd-shell/matugen.json` | — | live — `Config/Wal.qml`'s `FileView` watches the output |
| `[templates.ghostty]` | `~/.config/ghostty/matugen/theme` → `~/.config/ghostty/themes/matugen` | `busctl` call to ghostty's `reload-config` D-Bus action | live |
| `[templates.btop]` | `~/.config/btop/matugen/matugen.theme` → `~/.config/btop/themes/matugen.theme` | `pkill -USR2 -x btop \|\| true` | live |
| `[templates.cava]` | `~/.config/cava/matugen/config` → `~/.config/cava/config` | `SIGUSR2` to any bare `cava` PID (skips `-p ...` instances, so the bar's own cava is never touched) | live, terminal instance only |
| `[templates.yazi]` | `~/.config/yazi/matugen/theme.toml` → `~/.config/yazi/theme.toml` | — | next launch — yazi's own IPC needs `$YAZI_ID`, unreachable from a hook |
| `[templates.nvim]` | `~/.config/nvim/matugen/colorscheme.lua` → `~/.config/nvim/colors/matugen.lua` | — | live — nvim's own `lua/matugen_watch.lua` watches the output, not matugen |
| `[templates.vesktop]` | `~/.config/vesktop/themes/matugen/caelus-accent.css` → `~/.config/vesktop/themes/caelus-accent.theme.css` | — | live — Vencord watches its themes folder |
| `[templates.spotify]` | `~/.config/spicetify/Themes/caelus24/matugen/caelus-accent.css` → `~/.cache/caelus24/caelus-accent.css` | copies the render into Spotify's `xpui` folder | live — `theme.js` polls the copied file every 2s; see [spicetify](spicetify.md) |
| `[templates.firefox]` | `~/.config/matugen/templates/firefox-colors.css` → `~/.cache/rd-shell/firefox-colors.css` | — | next Firefox start — chrome/content CSS parses once |
| `[templates.bat]` | `~/.config/matugen/templates/bat.tmTheme` → `~/.config/bat/themes/matugen.tmTheme` | `bat cache --build` | next invocation — see [bat](bat.md) |
| `[templates.kde]` | `~/.config/matugen/templates/kde-colors.colors` → `~/.local/share/color-schemes/Matugen.colors` | copies to `Matugen2.colors`, applies whichever of the two names isn't currently active with `plasma-apply-colorscheme` | live |
| `[templates.papirus-accent]` | `~/.config/matugen/templates/papirus-accent.txt` → `~/.cache/rd-shell/papirus-accent.txt` | runs `scripts/papirus-accent.sh` detached (`setsid -f`) | next icon lookup |
| `[templates.gtk]` | `~/.config/matugen/templates/gtk-colors.css` → `~/.cache/rd-shell/gtk-colors.css` | — | next launch — neither GTK3 nor GTK4 watches `gtk.css` |

¹ In `matugen/bar.toml`, not `dotfiles/matugen/config.toml` — the one
template run separately so no app template below it can ever block the bar.

### Why the Spotify template copies instead of rendering in place

`[templates.spotify]`'s `output_path` is a cache file, not `xpui` directly,
because right after a Spotify update `xpui` can be root-owned or briefly
missing until `spicetify apply` restores it — a template whose
`output_path` can't be written aborts the *entire* matugen run, which would
take the rest of the app themes down with it. The copy in the `post_hook`
fails quietly instead (`|| true`); the next wallpaper switch puts it back.

## Harmonized ANSI colours

`[config.custom_colors]` in `dotfiles/matugen/config.toml` defines six fixed
hues rather than letting every "red"/"green"/etc. role fall out of the
wallpaper's own Material palette:

```toml
[config.custom_colors]
red     = { color = "#e5534b", blend = true }
green   = { color = "#57ab5a", blend = true }
yellow  = { color = "#c69026", blend = true }
blue    = { color = "#539bf5", blend = true }
magenta = { color = "#b083f0", blend = true }
cyan    = { color = "#39c5cf", blend = true }
```

A tonal-spot scheme (see below) is one hue in five tones — deriving an ANSI
palette purely from wallpaper roles would make red, green and blue the same
colour, so terminal output, `ls`, btop's meters and fetchit's labels would
all go monochrome. `blend = true` instead pulls each fixed hue at most 15°
toward the wallpaper's source colour, so the six stay visually distinct
while still reading as "this wallpaper's" palette. Each renders the usual
matugen role ladder (`red`, `on_red`, `red_container`, `on_red_container`)
at the tones of whatever `--mode` was rendered with, so they stay legible on
`surface` in both light and dark.

Every per-app template that needs a fixed hue (ghostty's ANSI 1–6, btop's
box outlines and graph gradients, cava's terminal-instance colours, nvim's
syntax groups) reads these same six roles — see each app's own page.

## Scheme, mode, and `--prefer saturation`

Every matugen call in `scripts/wallpaper-apply.sh` passes:

```
matugen image <path> --prefer saturation --type "scheme-$mgscheme" --mode "$mgmode" ...
```

- **`--prefer saturation`**: required, not cosmetic. Where an image offers
  more than one candidate source colour, matugen normally asks interactively
  — and there's no terminal attached when this runs detached from a
  keybind, so an unanswered prompt is a failed render. Picking the most
  saturated candidate is also the right call for an accent colour: the hue
  the wallpaper is *about*, not its average.
- **scheme/mode**: resolved once by `scripts/matugen-scheme.sh`, shared by
  both the real apply and the wallpaper switcher's preview so they can never
  disagree about what colours are about to show up:
  - `scheme` — read from `Config/Caelus.qml`'s `scheme` property, fixed at
    `"tonal-spot"`. One property, one place it's written down, so nothing
    else repeats the string.
  - `mode` — read from `Config/Caelus.qml`'s `colorMode` (`light`/`dark`/
    `smart`), falling back to `dark` if unset or unrecognised.
- Both fall back to `tonal-spot`/`dark` if `Config/Caelus.qml` can't be read
  at all, so a broken or moved QML file degrades to a sane default rather
  than passing garbage straight through to matugen's `--type`/`--mode`
  flags.

## Adding a template for a new app

1. Write the template body somewhere sensible — either under the app's own
   `dotfiles/<app>/matugen/` (the pattern most apps here use) or as one more
   file in `dotfiles/matugen/templates/` (the pattern for apps with nothing
   else to ship, like GTK or KDE). Use `{{colors.<role>.default.hex}}`
   placeholders — see any existing template for the exact role names
   (`surface`, `on_surface`, `primary`, the six custom hues, etc.).
2. Add an entry to `dotfiles/matugen/config.toml`:
   ```toml
   [templates.myapp]
   input_path = '~/.config/myapp/matugen/theme'
   output_path = '~/.config/myapp/theme.conf'
   post_hook = 'signal-or-reload-command || true'   # optional
   ```
   Always end a `post_hook` with `|| true` (or otherwise swallow its exit
   status) — a `post_hook` failure is still a matugen run failure, and a
   render must never be allowed to block the rest of the wallpaper switch.
3. Link the template file itself into `dotfiles/` so `install.sh` puts it in
   place (see [Installing over an existing config](../installation/existing-config.md)
   for how the generic per-file link loop works) — matugen renders from the
   **linked** `input_path`, not the repo path directly.
4. Re-render to test: `scripts/wallpaper-apply.sh --restore`.

### Why every template ships even for apps you don't have

matugen aborts its **entire** run the moment it hits a `[templates.*]` entry
whose `input_path` doesn't exist — it doesn't skip that one template and
keep going. That's why `dotfiles/` ships the `vesktop` and `spicetify`
templates (and every other one) unconditionally, regardless of whether you
actually have Vesktop or Spotify installed: leaving one out for an app you
don't use would silently break every other app's theme render on top of it.
