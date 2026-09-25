# ghostty

`hypr/dotfiles/ghostty/` is linked as the **whole** `~/.config/ghostty`
directory (`link "$REPO/hypr/dotfiles/ghostty" "$HOME/.config/ghostty"` in
`install.sh`) — not per-file, unlike the rest of `dotfiles/`. That's how it
sits on the machine this rice was copied from: ghostty's config was already
a whole-directory symlink there, so the installer recreates the same shape
rather than copying files into a real directory.

## Notable settings (`config.ghostty`)

The config is deliberately small — most of ghostty's surface (padding,
background opacity/blur, cursor style, shell integration, window-save-state)
is left at ghostty's own defaults; nothing here overrides them:

| Setting | Value | What it does |
|---|---|---|
| `window-height` / `window-width` | `50` / `200` | terminal cell grid on new-window open |
| `font-family` | `"caelusevka"` | the same custom Iosevka build used for bar label text — see [Cursor, icons & fonts](cursor-icons-fonts.md) |
| `font-size` | `20` | |
| `theme` | `matugen` | loads `themes/matugen`, the matugen-rendered file below |
| `keybind` | `ctrl+s=new_split:right` | split right |
| `keybind` | `ctrl+tab=goto_split:next` | cycle splits |
| `keybind` | `ctrl+shift+w=close_surface` | close the current split/tab |
| `keybind` | `ctrl+shift+n=unbind` | unbinds ghostty's own new-window action — new windows only ever come from Hyprland's `Super+Q` (see below), since the in-app action can't set fetchit's marker and would open a silent window |

`opacity`/`blur`, cursor shape/blink, `shell-integration`, and
`window-save-state` are all absent from the file, i.e. left at whatever
ghostty ships as its own default for each.

## `themes/`

- `caelus` — the static caelus palette, usable by hand (`theme = caelus`)
  if you turn dynamic colour off.
- `matugen` — the live-rendered file `theme = matugen` actually loads.
  **Gitignored** — it's render output, not a file the repo carries (the
  template that produces it, below, is what's committed).

## The matugen theme, and how it live-reloads

- Template: `hypr/dotfiles/ghostty/matugen/theme` → `[templates.ghostty]` in
  `dotfiles/matugen/config.toml` → rendered to `themes/matugen` on every
  wallpaper switch.
- Palette mapping (the same canonical scheme every terminal-colour template
  in this repo uses): `background`/`foreground` = `surface`/`on_surface`;
  ANSI 0/8 = `surface_container_high`/`outline`; 1–6 and 9–14 = the six
  harmonized custom hues (red/green/yellow/blue/magenta/cyan) at their
  container tones; cursor = `primary`/`on_primary`; selection =
  `primary_container`/`on_primary_container`.
- **Live reload**: ghostty has no file-watch for theme files — its own docs
  say a reload needs a keybind, menu action, or restart. The `post_hook`
  instead activates the *running* GTK app's `reload-config` action over
  D-Bus (`org.gtk.Actions` on the well-known name `com.mitchellh.ghostty`,
  via `busctl` — the same action ghostty's own "Reload Config" keybind and
  command-palette entry call), which reloads every open window/tab
  immediately with no new window and no signal sent to any focused surface.

## The `Super+Q` / working-directory trick

`Super+Q` in `hypr/hyprland.lua` runs:

```
ghostty +new-window --working-directory=$HOME/.local/state/ghostty/new-window
  || ghostty --working-directory=$HOME/.local/state/ghostty/new-window
```

`+new-window` talks to a *running* ghostty instance to open a new window in
it (needed so fetchit's first-window marking and split behaviour stay consistent
with an existing session); the `||` falls back to a plain `ghostty` launch
for the very first window, when no instance is running yet to talk to.
Either way, ghostty refuses to start in a working directory that doesn't
exist — `install.sh` creates
`~/.local/state/ghostty/new-window` up front so the first terminal of a
fresh install doesn't fail on a missing directory.
