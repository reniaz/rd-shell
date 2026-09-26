# What install.sh does

A step-by-step walkthrough. It's safe to re-run at any point — every step
checks before it changes anything.

### 1. Repositories

Enables the COPRs `lionheartp/Hyprland`, `errornointernet/quickshell`,
`scottames/ghostty`, `lihaohong/yazi`, prompting for each unless `-y` is
passed. If an NVIDIA card is detected, also offers RPM Fusion free/nonfree.

### 2. Dependencies

Checks a table of `command → package → required|optional` entries (things
like `qs`/`quickshell`, `hyprctl`/`hyprland`, `nmcli`/`NetworkManager`,
`matugen`/`matugen`, `jq`, `wl-copy`, `playerctl`, `ddcutil`, `flatpak`,
`qalc`/`qalculate` (the launcher's calculator), `swappy`/`swappy`
(screenshot annotation), and more), plus a handful of packages with no
binary to probe for (`xdg-desktop-portal-hyprland`, `polkit-kde` — the
authentication agent `hyprland.lua` now autostarts, so `pkexec`/GUI-admin
prompts work under Hyprland — `plasma-integration`, `adw-gtk3-theme`,
`plasma-nm`). This is also where the toolchain nvim's
bundled plugins need is installed, all as optional dependencies:
`nodejs22`+`nodejs22-npm-bin`, `python3-pip`, `unzip`, `ripgrep`, `fd-find`,
`gcc`+`gcc-c++`+`make`, `golang` (see [nvim](../dotfiles/nvim.md#toolchain-and-plugins)
for what each one is for). Anything missing is offered for install in one
batch.

### 3. fetchit and wayvibes (source builds)

Neither has a Fedora package. Both build into
`${XDG_CACHE_HOME:-$HOME/.cache}/qs-bar-build` (never inside the repo) and are
skipped if already on `PATH`. `fetchit` installs unprompted if its build
succeeds; `wayvibes` is opt-in (keypress sounds, needs your own soundpack).

### 4. Fonts

Links a fontconfig rule that keeps the "Material Symbols Rounded" family
resolving to the full icon font rather than some other app's subset of it,
then offers to download the font itself if it isn't already resolving
correctly. Also offers to install the bundled `caelusevka` font from
`assets/fonts/`.

### 5. Cursor theme

Downloads Bibata-Original-Classic from its GitHub release into
`~/.local/share/icons`, if not already there.

### 6. Icon theme (Papirus)

Installs Papirus-Dark user-level (`DESTDIR=~/.local/share/icons`, no sudo)
and `papirus-folders` into `~/.local/bin`, so folder colours can follow the
wallpaper accent later.

### 7. Config

Symlinks the whole repo to `~/.config/quickshell/rd-shell`, links the four
Hyprland files (`hyprland.lua`, `hyprland-gui.lua`, `hypridle.conf`,
`hyprlock.conf`) into `~/.config/hypr/`, links `hypr/dotfiles/ghostty` as the
whole `~/.config/ghostty` directory, and relinks the three scripts
(`keybinds.sh`, `mic-toggle.sh`, `screenshot.sh`) that `hyprland.lua` calls by
their `~/.config/hypr/scripts/` path. Creates the ghostty working-directory
state dir so `Super+Q` doesn't fail on a directory that doesn't exist yet.

The session-lock fallback script (`scripts/lock.sh`, `Super+L`) and the
ghostty cursor-trail shader (`hypr/dotfiles/ghostty/shaders/`) need no extra
step of their own here — both already live inside directories the two links
above cover (the whole-repo symlink and the ghostty directory symlink,
respectively).

If Hyprland already auto-generated (or you hand-wrote) a
`~/.config/hypr/hyprland.conf`, it's backed up here (copied, original left
in place), not deleted — see [Installing over an existing
config](existing-config.md) for the warning about what happens to it on your
next Hyprland restart.

### 8. App dotfiles

Links every file under `dotfiles/` to its matching `~/.config/<app>` path —
matugen's own config and every per-app template (btop, cava, yazi, nvim,
vesktop, spicetify, fetchit, bat). All of them ship regardless of whether you
have the app installed, because matugen aborts its entire run on the first
missing `input_path` it's configured with. `btop.conf` and `cava/config` are
skipped by this generic loop — they're handled by their own steps further
down (12 and 13) since both are rewritten wholesale by their own app/by
matugen, which a plain symlink doesn't survive cleanly. nvim is linked
file-by-file the same as everything else here — see [nvim](../dotfiles/nvim.md)
for what that covers and how an existing config of yours is backed up.

### 9. nvim plugins (headless)

Runs `nvim --headless "+Lazy! restore" +qa` right after nvim's config is
linked, so the first real launch of nvim isn't a plugin download in the
middle of typing. Guarded, never fatal — checks `git`/`gcc`/`g++`/`make` are
on `PATH` first (warns per missing one) and falls back to nvim installing
everything itself on its own next launch if the headless sync fails. See
[nvim](../dotfiles/nvim.md#toolchain-and-plugins).

### 10. GTK3/GTK4/libadwaita theming

Writes/updates `settings.ini` (theme, icon theme, cursor theme+size) for both
GTK versions, appends a matugen `@import` to `gtk.css` if missing, and sets
the matching `gsettings` keys.

### 11. KDE/Qt icon + cursor theme

Sets `kdeglobals`' icon theme to Papirus-Dark and `kcminputrc`'s cursor theme
and size via `kwriteconfig6`, notifying running apps.

### 12. btop theme

`btop.conf` rewrites itself wholesale on exit, so this isn't a plain
symlink: if `~/.config/btop/btop.conf` already exists, only its
`color_theme` line is patched to `"matugen"` (backed up first if it had to
change) or appended if missing — nothing else in your file is touched. If
it doesn't exist yet, `dotfiles/btop/btop.conf` is copied in whole. See
[btop](../dotfiles/btop.md#how-its-installed).

### 13. cava theme

`~/.config/cava/config` is entirely matugen-owned and gets rewritten on
every wallpaper switch, so like btop.conf this is a copy, not a symlink —
and only a seed for a fresh machine: `dotfiles/cava/config` is copied in
only if nothing is at that path yet; an existing file (yours, or from an
earlier install) is left alone. See [cava](../dotfiles/cava.md#how-its-installed).

### 14. Starship

`starship` has no Fedora or COPR package, so if it isn't already on `PATH`
this offers to install it from its own curl installer at starship.rs into
`~/.local/bin` (no sudo). Once it's there, one `eval "$(starship init
bash)"` line is appended to `~/.bashrc` (backed up first) unless it's
already wired — the theming itself is matugen's job, via
`[templates.starship]` rendering `~/.config/starship.toml` on every
wallpaper switch (see [matugen (config reference)](../dotfiles/matugen.md));
this step only makes bash read the result.

### 15. Terminal defaults

Writes `~/.config/environment.d/terminal.conf` and
`~/.config/xdg-terminals.list` to point default-terminal lookups at ghostty —
only if neither file already exists.

### 16. Wallpapers

Clones `LainOS-wallpapers` into `~/Pictures/wall/LainOS-wallpapers` (opt-in,
~290MB) and copies this repo's own `wallpapers/` on top without overwriting
anything already there.

### 17. hyprexpo plugin

Installs the plugin's build dependencies (`cmake`, `meson`, `ninja-build`,
`pkgconf`, `gcc-c++`, `hyprland-devel`) first, then adds and enables the
`hyprexpo` Hyprland plugin via `hyprpm` — only possible inside a running
Hyprland session (`hyprpm` talks to the live compositor over its socket).
Prints the manual command otherwise. A build failure prints the exact path
to `hyprpm`'s own build log (`~/.cache/qs-bar-build/hyprexpo.log`) instead of
just failing silently.

### 18. Notification daemon

Masks `swaync`, `dunst` and `mako` (whichever are installed) so the shell can
own the `org.freedesktop.Notifications` D-Bus name — stopping alone isn't
enough since all three are D-Bus activated.

### 19. Audio

Enables and starts `pipewire.socket`, `pipewire-pulse.socket` and
`wireplumber.service`, then patches a PipeWire drop-in the Iriun Webcam
package ships (missing a `nofail` flag) that can otherwise crash-loop the
whole audio stack at boot.

### 20. Idle

Offers to enable `hypridle.service` (locks after 5 minutes, blanks displays
after 10 — `hypridle.conf` is inert without the daemon running).

### 21. First colour render

Runs `scripts/wallpaper-apply.sh` against the fallback wallpaper so the bar,
app themes and lock screen colours all exist before first launch instead of
pointing at files matugen hasn't written yet.

### 22. KDE colour scheme

Applies the first Matugen KDE colour scheme via `plasma-apply-colorscheme`,
if the render above produced one and it isn't already active. Every
subsequent wallpaper switch handles this itself through
`[templates.kde]`'s own `post_hook` — see [matugen (config reference)](../dotfiles/matugen.md).

### 23. bat theme

Builds `bat`'s theme cache (`bat cache --build`) once the matugen render has
produced `~/.config/bat/themes/matugen.tmTheme`, so `--theme=matugen`
resolves immediately instead of waiting for the next wallpaper switch. See
[bat](../dotfiles/bat.md).

### 24. Spotify + spicetify

Installs Spotify as a **per-user** flatpak (adding the `flathub` remote
`--user` first if needed — per-user so spicetify can patch its files
without `sudo`), installs spicetify from its own upstream curl installer
into `~/.spicetify` plus the Marketplace custom app, waits (automatically, up to 20s) for Spotify's
first-run prefs file if it isn't there yet, points spicetify at the install,
and applies the `caelus24` theme with matugen's rendered colours. If Spotify
is already installed system-wide, this step is skipped and instructions to
switch are printed instead (also in the end-of-run Summary). See
[spicetify](../dotfiles/spicetify.md) for the full detail, including the
exact `spicetify config` keys and the post-update caveat.

### 25. Firefox

If a Firefox profile is found, links the profile's `chrome/rd-shell` to the
repo's `firefox/`, writes the `userChrome.css`/`userContent.css` import
stubs, and enables `toolkit.legacyUserProfileCustomizations.stylesheets` in
`user.js`.

### 26. Summary

Prints the machine-specific edits you still need to make by hand — see
[Fresh install](fresh-install.md#after-the-script-finishes) for the list.
