# bat

## What `dotfiles/bat/config` sets

The whole file is one line:

| Setting | Value | What it does |
|---|---|---|
| `--theme` | `"matugen"` | the only override — everything else (`--style`, `--paging`, `--wrap`, line numbers, grid, header) is left at bat's own defaults |

Style, paging and the rest aren't touched here — if you want bat's usual
`--style=numbers,changes` grid or `--paging=never`, add them to this file
yourself; nothing about the matugen pipeline needs them.

## The matugen theme, and why `bat cache --build` matters

- Template: `dotfiles/matugen/templates/bat.tmTheme` → `[templates.bat]` in
  `dotfiles/matugen/config.toml` → rendered to
  `~/.config/bat/themes/matugen.tmTheme` on every wallpaper switch.
- bat has no file-watch or live-reload — every invocation is a fresh process
  that reads a **compiled cache**, not the `.tmTheme` file directly. So the
  template's `post_hook` runs `bat cache --build` (redirected, `|| true`)
  right after every render, compiling the new theme into that cache. Without
  this step, `--theme="matugen"` would keep showing the *previous*
  wallpaper's colours until something rebuilt the cache by hand.
- `install.sh`'s "bat theme" step also runs `bat cache --build` once at
  install time (if `~/.config/bat/themes/matugen.tmTheme` already exists),
  so `--theme=matugen` resolves correctly on the very first invocation
  instead of waiting for the first wallpaper switch.
- Net effect: colours are current as of the **last wallpaper switch**, on
  bat's *next* invocation after that switch — never live within a single
  run, but never more than one switch stale either.

## Does bat theme `man` pages too?

Not in this rice, as shipped: nothing under `dotfiles/`, `hypr/`, or
`scripts/` sets `$MANPAGER` (checked — no reference anywhere in the repo).
`man` therefore renders with whatever pager Fedora's `man-db` defaults to,
untouched by bat's theme. If you want bat's well-known `man` trick yourself,
add to your shell config:

```bash
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
```

which would then also pick up `--theme=matugen` from this config and follow
the wallpaper the same way `bat <file>` does — but that's a change you'd be
opting into, not something this rice sets up for you.

`bat` is an optional dependency in `install.sh`.
