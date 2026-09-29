# cava

`~/.config/cava/config` is entirely matugen-owned — the file cava reads by
default with no `-p` flag, i.e. what you get running plain `cava` by hand in
a terminal.

## Notable settings

cava 0.10.2 has no `theme=`/include directive, so there's no way to keep a
hand-owned config next to a separate generated colour file the way ghostty's
`theme =` line does. The whole file is therefore the matugen template —
every section except `[color]` is deliberately left out, so cava falls back
to its own built-in defaults for everything else:

| Setting | Value | Why |
|---|---|---|
| bars / framerate | *(unset — cava default)* | no per-machine reason to override; auto bar count/width, default 60fps |
| input method | *(unset — cava default)* | autodetects a `pulse` input; the terminal instance isn't picky the way the bar's own instance is (see below) |
| smoothing | *(unset — cava default)* | no `[smoothing]` section, cava's noise-reduction default applies |
| output | *(unset — cava default)* | noncurses terminal output |
| `[color] gradient` | `1` | 3-stop gradient instead of a flat colour |
| `[color] gradient_color_1/2/3` | wallpaper's `primary` → `secondary` → `tertiary` (bottom to top) | the wallpaper's own three Material hues, not the fixed six-hue ANSI set ghostty uses — reads as "this wallpaper," not a generic rainbow. All three are base-tone roles (~40 tone in light mode, ~80 in dark) so they hold contrast against the background in both modes. |
| `[color] background` | *(unset, not even `default`)* | keeps whatever the terminal is already showing — ghostty's own matugen-rendered background — instead of cava pinning its own colour on top |

## The matugen wiring

- Template: `dotfiles/cava/matugen/config` → `[templates.cava]` in
  `dotfiles/matugen/config.toml` → rendered to `~/.config/cava/config` on
  every wallpaper switch.
- `post_hook`: sends `SIGUSR2` (cava's "reload colours only" signal) to any
  running **bare** `cava` process — matched by checking each `cava` PID's
  `/proc/<pid>/cmdline` for a `-p` flag, so a signalled process is never one
  started with an explicit `-p`. That's what keeps the next section's bar
  visualizer untouched.

## How it's installed

Like `btop.conf`, `~/.config/cava/config` is copied rather than symlinked —
matugen rewrites the whole file on every wallpaper switch, and a symlink
back into a tracked repo file would mean the repo copy changes every time
you switch wallpapers. `install.sh`'s "cava theme" step only seeds a fresh
machine: if `~/.config/cava/config` already exists (from a previous run, or
your own file), it's left alone entirely; otherwise `dotfiles/cava/config`
is copied in as a starting point. Either way, the very next wallpaper
switch (including the installer's own first-colour-render step) overwrites
it with a real render, so this copy only matters for the brief window
before that happens.

## Tweaking it

Since the whole file is matugen-owned, edit
`dotfiles/cava/matugen/config` (the template, with `{{colors...}}`
placeholders), not `~/.config/cava/config` directly — a wallpaper switch
overwrites the latter. Trigger a re-render with
`scripts/wallpaper-apply.sh --restore` after editing.

## Not the same cava as the bar's visualizers

The media pill, the media popup's spectrum, and the desktop Spotify card's
visualizers are **not** reading this file at all. `Services/Cava.qml`
launches its own, completely separate cava processes —
`cava -p ~/.cache/rd-shell/cava.conf` — with an explicit `-p`, so it never
looks at `~/.config/cava/config` and this page's template can't affect it
(and the `post_hook` above deliberately skips it for the same reason, so a
terminal-cava colour reload never restarts the bar's feed).

Those instances are also fed differently: `method = pulse` targeted at a
capture proxy, not the default sink's monitor, with the streams each one
hears wired up live over PipeWire link management (the QML equivalent of
`pw-link`, in `Services/CavaFeed.qml`):

- **`rd-cava`** — the bar's islands (media pill bars, media popup ring,
  workspace beat glow). Every playback stream except **wayvibes'** key
  clicks: Spotify, Firefox, games, anything that is sounding.
- **`rd-spotify-cava`** — the desktop Spotify card. **Spotify only** while
  Spotify is playing, even with other apps sounding over it. While Spotify
  isn't playing the card reads the `rd-cava` mix instead, so it still moves
  with everything else (wayvibes excluded).

Each process only runs while one of its streams is actually sounding (its
PipeWire link is `active`, not `paused`), and every visualizer shares one
normaliser tuning (`CavaNormalize.js`), so the island and the desktop card
react to the same hit the same way. A terminal cava started with
`PULSE_PROP='node.name=rd-cava-<name> node.autoconnect=false'` gets the
islands' mix; `rd-spotify-cava-<name>` gets Spotify's. Its generated config
lives in `~/.cache/rd-shell/`, not under `~/.config/cava`, since it's
runtime/cache state the same way `Services/Wallpapers.qml` already treats
that directory, not a dotfile meant for hand editing.
