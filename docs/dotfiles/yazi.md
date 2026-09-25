# yazi

Two separate files cover yazi: a behaviour config (`yazi.toml`) and a
matugen colour template (`matugen/theme.toml`) — don't confuse them, only
the second one is wallpaper-driven.

## Notable settings (`yazi.toml`)

`dotfiles/yazi/yazi.toml` (linked the same way as the rest of `dotfiles/`)
is minimal — one custom opener, everything
else (layout ratio, sort order, hidden-file visibility, previewers) left at
yazi's own built-in defaults:

| Setting | Value | What it does |
|---|---|---|
| layout ratio | *(unset — yazi default)* | parent/current/preview column widths use yazi's stock ratio |
| sorting | *(unset — yazi default)* | yazi's default sort (alphabetical, directories first) |
| hidden files | *(unset — yazi default)* | dotfiles hidden until toggled in-app |
| previewers | *(unset — yazi default)* | yazi's built-in preview handlers for images/text/archives |
| openers | one custom entry: `edit` → `nvim "$@"` (blocking, Unix) | routes "Edit" actions to nvim |


## The matugen theme (`matugen/theme.toml`)

- Template: `dotfiles/yazi/matugen/theme.toml` → `[templates.yazi]` in
  `dotfiles/matugen/config.toml` → rendered to `~/.config/yazi/theme.toml`
  on every wallpaper switch.
- **Yes, it's generated** — `theme.toml` is pure render output (not tracked
  as a dotfile you'd hand-edit) each time `scripts/wallpaper-apply.sh` runs.
- Yazi treats a user `theme.toml` as a **partial** override merged onto
  whichever of its two built-in presets (`theme-dark.toml`/
  `theme-light.toml`) matches the terminal's reported colour mode — so only
  the sections that need the wallpaper's colour are templated here
  (accent, folders, and per-filetype colours: image, media/av, archive,
  docs, exec, muted/borders); everything else (backgrounds, glyphs, layout)
  is left to whichever preset yazi picks. Since matugen re-renders this file
  per `--mode` on every switch, the same file is correct for both colour
  modes — whichever mode matugen was last run with is the one whose tones
  land here.
- No live reload: `ya emit`/`ya pub` (yazi's own IPC) need `$YAZI_ID`, only
  set inside a shell yazi itself spawned — unreachable from a matugen
  `post_hook`. A running yazi picks up the new theme on its next restart.

`yazi` is an optional dependency in `install.sh`, from its own COPR
(`lihaohong/yazi`).
