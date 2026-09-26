# Uninstall / revert

`install.sh` has no `--uninstall` flag; reverting means removing what it put
in place, by hand. Everything it touches is listed below — it's all links or
narrow file edits, so nothing here should surprise you.

## What it wrote, and where

```
~/.config/quickshell/rd-shell         -> this repo (symlink)
~/.config/hypr/{hyprland.lua,hyprland-gui.lua,hypridle.conf,hyprlock.conf}
                                       -> hypr/ in this repo (symlinks)
~/.config/hypr/scripts/*.sh           -> scripts/{keybinds,mic-toggle,screenshot}.sh
~/.config/ghostty                     -> hypr/dotfiles/ghostty (symlink)
~/.config/<app>/...                   -> dotfiles/<app>/... (symlinks, one per file)
~/.config/bat/                        -- config + rendered matugen theme/cache
~/.config/gtk-{3,4}.0/settings.ini    -- theme/icon/cursor keys set
~/.config/gtk-{3,4}.0/gtk.css         -- one @import line appended
~/.config/btop/btop.conf              -- color_theme key set to "matugen"
~/.config/environment.d/terminal.conf, ~/.config/xdg-terminals.list
                                       -- ghostty set as default terminal
~/.bashrc                             -- one starship-init line appended (only if starship is installed)
~/.local/bin/starship                 -- installed here if no Fedora/COPR package covered it
~/.config/vesktop/settings/settings.json
                                       -- .plugins.XSOverlay merged in (only if the file already existed)
$XDG_RUNTIME_DIR/rd-shell.log         -- shell's own log
~/.cache/qs-bar/                      -- claude-global.sh's transcript cache
~/.cache/rd-shell/                    -- rendered matugen colours (bar, firefox, gtk, lock)
~/.local/share/color-schemes/Matugen*.colors -- rendered KDE scheme
~/.local/share/icons/Papirus*, Bibata-Original-Classic
                                       -- user-level icon/cursor theme installs
~/.local/bin/papirus-folders          -- folder-colour CLI
~/.local/share/themes/adw-gtk3*       -- user-level GTK theme
~/.local/share/fonts/*.ttf            -- Material Symbols Rounded + caelusevka
<firefox profile>/chrome/rd-shell, chrome/matugen.css
                                       -> firefox/ in this repo, and the rendered colours file
<firefox profile>/chrome/userChrome.css, userContent.css
                                       -- import stubs written by install.sh
<firefox profile>/user.js             -- adds the legacyUserProfileCustomizations pref
```

Plus, outside the filesystem: RPM/COPR packages installed, `hyprexpo` added
via `hyprpm`, `swaync`/`dunst`/`mako` masked, `pipewire`/`wireplumber`/
`hypridle` services enabled, and several `gsettings`/`kwriteconfig6` keys set.

## Steps

1. **Remove the autostart line** from your Hyprland config
   (`exec-once = ~/.config/quickshell/rd-shell/launch.sh`), or just don't pick
   "Hyprland" (this config) at the login screen anymore.
2. **Remove the symlinks** listed above. Anything `install.sh` backed up when
   it replaced your own file (`<path>.bak-YYYYmmdd-HHMMSS`) can be moved back
   into place — see [Installing over an existing
   config](existing-config.md#rolling-back).
3. **Unmask your notification daemon** of choice —
   `systemctl --user unmask swaync.service` (or `dunst.service` /
   `mako.service`). `install.sh` masks all three regardless of which one you
   have, not just the one it finds.
4. **Disable services** you no longer want running:
   `systemctl --user disable --now hypridle.service`.
5. **Firefox**: delete `chrome/rd-shell`, `chrome/matugen.css`, and either
   restore your own `userChrome.css`/`userContent.css` from their `.bak-...`
   files or delete the two-line stubs. Remove the
   `toolkit.legacyUserProfileCustomizations.stylesheets` line from `user.js`
   if you don't want other chrome customisation either.
6. **Packages, fonts, themes, wallpapers** are left in place on purpose —
   they're not this rice's alone to remove (Papirus, adw-gtk3, Bibata, the
   COPR packages) and `dnf`/`hyprpm` are the right tools to remove them if you
   want them gone, not this script.
7. **Starship**: remove the appended `eval "$(starship init bash)"` block
   from `~/.bashrc` (and delete `~/.local/bin/starship` too, if you want it
   gone — it's the one binary `install.sh` puts there directly rather than
   through `dnf`, since Fedora has no package for it).
8. **Vencord XSOverlay plugin**: turn it back off in Vesktop → Settings →
   Vencord → Plugins if you don't want the call banner, or restore
   `~/.config/vesktop/settings/settings.json` from the
   `.bak-YYYYmmdd-HHMMSS` copy `install.sh` made right before it edited it.
   Either way, restart Vesktop afterwards.

There's no single command that undoes all of the above — `install.sh` is
one-directional by design, the same way it's safe to re-run: it only ever
checks and adds, never a coordinated "revert everything" path.
