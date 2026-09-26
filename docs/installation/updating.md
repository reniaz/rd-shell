# Updating / re-running

```bash
cd ~/coding/qs-bar   # wherever you cloned it
git pull
./install.sh         # or ./install.sh -y
```

`install.sh` is idempotent — every step checks its own state before changing
anything, so re-running it after a `git pull` is the normal way to pick up
config changes. Already-correct symlinks,
already-set gsettings keys, an already-wired `~/.bashrc` (starship),
already-masked daemons and already-enabled services all print `ok` and are
left alone; only what actually changed (a new dotfile, an updated Hyprland
bind script, a package that's now required) does anything.

Things worth knowing about re-running:

- If a target path was a plain file the *last* time you ran it, it's now a
  symlink — re-running won't re-back-up anything, it just confirms the link
  still points at the right place.
- The COPR/RPM Fusion and dependency-install steps only prompt for what's
  still missing; already-installed packages are skipped.
- The first-colour-render step re-runs `scripts/wallpaper-apply.sh` against
  whatever wallpaper is currently set (or the fallback if none is), so it's
  also how to re-render every app theme by hand if one drifted.
- `dotfiles/fetchit/init.lua`'s hand-typed OS/GPU lines and `hyprland.lua`'s
  monitor names are **not** re-generated — if you edited them for your
  machine, re-running `install.sh` doesn't touch them again (they're plain
  linked files, not templates).

To update just the rendered theme without the rest of the installer, use
`scripts/wallpaper-apply.sh --restore` (re-render against the last-set
wallpaper) or pick a new wallpaper with `Ctrl+Alt+F`.
