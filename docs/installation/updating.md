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

## If `git pull` complains

```
error: Your local changes to the following files would be overwritten by merge:
        hypr/hyprland.lua
Please commit your changes or stash them before you merge.
Aborting
```

The whole repo is symlinked into `~/.config/quickshell/rd-shell`, and
`hyprland.lua` and the ghostty config are symlinked the same way — so editing
one *through* its `~/.config` link (monitor names/positions in `hyprland.lua`,
most commonly) edits a file this clone tracks. When an update changes that same
file, `git pull` stops and applies nothing. Shelve your edits, pull, and put
them back:

```bash
git diff             # what you changed, for reference
git stash            # set your edits aside
git pull             # now a clean fast-forward
git stash pop        # put your edits back on top
./install.sh
```

If `git stash pop` reports a conflict, open the file it names. Each conflict
shows the new version between `<<<<<<<` and `=======`, and your edit between
`=======` and `>>>>>>>`. Keep the lines you want, delete the three marker
lines, then:

```bash
git reset -q         # clear the conflict state, keep the file as you fixed it
git stash drop       # the stash is applied, drop it
./install.sh
```

`install.sh` refuses to run while any tracked file still has conflict markers
in it, rather than link a broken config into `~/.config/hypr`.

## Things worth knowing about re-running

- If a target path was a plain file the *last* time you ran it, it's now a
  symlink — re-running won't re-back-up anything, it just confirms the link
  still points at the right place.
- The COPR/RPM Fusion and dependency-install steps only prompt for what's
  still missing; already-installed packages are skipped.
- The first-colour-render step re-runs `scripts/wallpaper-apply.sh --restore`
  against whatever wallpaper is currently set (the fallback only on a first
  install, before any wallpaper has ever been set), so re-running is also how
  every rendered app theme gets repaired if one was broken — a fixed
  `dotfiles/matugen/templates/*` template reaches `~/.config/starship.toml`
  and friends this way, without waiting for the next wallpaper switch.
- `dotfiles/fetchit/init.lua`'s hand-typed OS/GPU lines and `hyprland.lua`'s
  monitor names are **not** re-generated — if you edited them for your
  machine, re-running `install.sh` doesn't touch them again (they're plain
  linked files, not templates; see [If `git pull` complains](#if-git-pull-complains)). Keybinds are different and don't have this problem: the
  in-app keybind manager writes `~/.config/hypr/keybind-overrides.lua`,
  outside the repo, and `Local/binds.lua` is gitignored, so neither ever conflicts — see [keybinds](../keybinds.md).
- If an edit you made through a symlink seems to have vanished after
  updating, check for a `.bak-YYYYmmdd-HHMMSS` next to it: some editors save
  by writing a new file and renaming it over the old path, which replaces the
  symlink itself with a plain file instead of editing the linked repo file in
  place. `install.sh` treats that the same as any other pre-existing file —
  see [Installing over an existing config](existing-config.md) — backs it up
  and relinks it, rather than leaving a config it can no longer tell apart
  from a stray real file.

To update just the rendered theme without the rest of the installer, use
`scripts/wallpaper-apply.sh --restore` (re-render against the last-set
wallpaper) or pick a new wallpaper with `Ctrl+Alt+F`.
