# spicetify

`dotfiles/spicetify/Themes/caelus24/` is a [spicetify](https://spicetify.app)
theme (`caelus24`) for Spotify, linked to
`~/.config/spicetify/Themes/caelus24/`.

## What the theme changes

Not a recolour of stock Spotify — the brief was "a terminal application that
feels modern," with [system24](https://github.com/refact0r/system24)'s
*caelus* palette (the same one this whole rice is built on) as the
reference:

| File | What it does |
|---|---|
| `user.css` | the actual restyle: square corners everywhere (`--unrounding: on`), 2px panel borders, 12px gaps on a black gutter, panel-name notches cut into panel borders, monospace/lowercase chrome, one accent colour, no shadows/blur/gradients. Both sliders are drawn as block meters (`████░░░░`), the same visual language as btop/tmux. Spotify's own icons stay (`currentColor`-tinted through `user.css`), not swapped for an icon font — an earlier icon-swap approach broke silently every time Spotify redrew an icon. |
| `color.ini` | two palettes, `[caelus]` (the shell's normal dark theme) and `[caelus-dim]` (a dimmer sibling with the ground pulled down and accents pulled back a step). Each key mirrors a `system24-caelus.theme.css` variable by name in a comment, so the two stay checkable against each other by hand. |
| `theme.js` | one runtime job — polls a `/caelus-accent.css` endpoint and swaps its text into an injected `<style>` tag every 2 seconds. This is the live wallpaper-colour piece; see below. |
| `matugen/caelus-accent.css` | the matugen template `theme.js` polls for (see [matugen pipeline](../theming/matugen-pipeline.md)). |

## How the accent actually reaches Spotify — no restart needed

matugen's `[templates.spotify]` renders `matugen/caelus-accent.css` and
copies the result into Spotify's `xpui` static assets on every wallpaper
switch (see [matugen (config reference)](matugen.md) for the exact
`input_path`/`output_path`/`post_hook`). `theme.js` — already running inside
Spotify, injected once by `spicetify apply` — polls that file every 2
seconds (`fetch("/caelus-accent.css", { cache: "no-store" })`) and swaps its
CSS into a live `<style>` tag when it changes. That means:

- **No `spicetify apply`/`refresh` runs on a wallpaper switch** — only a
  plain file copy. `spicetify apply`/`backup apply` is a one-time (or
  post-Spotify-update) step that patches `user.css`/`theme.js`/`color.ini`
  into Spotify's own files; after that, `theme.js` itself is what keeps
  pulling new colours.
- **Spotify does not need to restart** for a new wallpaper's accent to show
  — it lands within about two seconds of the copy, live, in a client that's
  already open.
- If the copy fails (Spotify mid-update, `xpui` briefly unwritable —
  see [matugen (config reference)](matugen.md#why-the-spotify-template-copies-instead-of-rendering-in-place)),
  `theme.js`'s fetch just 404s that tick and keeps whatever accent was last
  applied — it "fails closed," per the file's own comment, showing
  `color.ini`'s static orange rather than nothing.

## `config-xpui.ini` — the settings that matter

spicetify's own config, `~/.config/spicetify/config-xpui.ini`, is what
spicetify itself writes/reads (not something this repo ships a template
for) — `install.sh`'s "spicetify" step sets it with a fixed sequence of
`spicetify config <key> <value>` calls, all idempotent (safe to re-run):

| Key | Value `install.sh` sets | What it does |
|---|---|---|
| `spotify_path` | detected per-user flatpak files path (`~/.local/share/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify`) | where spicetify patches Spotify's own files |
| `prefs_path` | `~/.var/app/com.spotify.Client/config/spotify/prefs` | Spotify's own flatpak prefs file (per-user flatpak *data* always lives under `~/.var/app/...`, regardless of whether the flatpak *install* itself is per-user or system-wide) |
| `current_theme` | `caelus24` | which theme directory under `Themes/` is active |
| `color_scheme` | `caelus` | which `[section]` of `color.ini` to use — swap to `caelus-dim` for the dimmer sibling |
| `home_config` | `1` | apply the theme to Spotify's Home page too, not just the rest of the chrome |
| `sidebar_config` | `0` | leave the sidebar's own layout config alone |
| `experimental_features` | `1` | required for `inject_css`/`inject_theme_js` to take effect on current Spotify builds |
| `custom_apps` | `marketplace` | appended once — `install.sh` checks `config-xpui.ini` for an existing `marketplace` entry first, since `spicetify config` *appends* to this key rather than replacing it, and re-adding it on every run would otherwise duplicate the entry |

Keys spicetify manages on its own that `install.sh` never touches directly
(left at whatever spicetify itself defaults or last wrote): `inject_css`,
`inject_theme_js`, `replace_colors`, `extensions`, `overwrite_assets` — all
consistent with the theme working as described above (CSS+JS injected,
colours replaced, no extensions, no asset overwriting).

## Install: Spotify as a per-user flatpak, then spicetify

`install.sh` installs Spotify itself as a **per-user** flatpak, installs
spicetify from its own upstream installer, then points spicetify at that
install and applies the `caelus24` theme — no manual `spicetify apply`
needed after a fresh install.

1. **Spotify** — `flatpak install --user flathub com.spotify.Client`, adding
   the `flathub` remote as a `--user` remote first
   (`flatpak remote-add --user --if-not-exists flathub
   https://flathub.org/repo/flathub.flatpakrepo`) if it isn't already there.
   Detected first via `flatpak info --system com.spotify.Client` / `flatpak
   info --user com.spotify.Client`, so an existing install (either scope)
   is never touched or reinstalled.
2. **spicetify itself** — not a distro package: installed via spicetify's
   own upstream curl installer
   (`curl -fsSL .../spicetify-cli/main/install.sh | sh`), which puts the
   binary at `~/.spicetify/spicetify`, no `sudo`. Skipped if `spicetify` is
   already on `PATH` or already at that path. Its closing "install
   Marketplace?" prompt is skipped (run without a terminal, so `-y` never
   stalls on it).
3. **Marketplace** — the release zip from `spicetify/marketplace`, unpacked
   into `~/.config/spicetify/CustomApps/marketplace` unless it's already
   there. `custom_apps marketplace` is only set when that folder exists.
4. **Config + apply** — the `config-xpui.ini` keys above, then
   `spicetify backup apply` to patch the theme into Spotify's own files.

**Why per-user, not system-wide:** spicetify has to write its own patches
into Spotify's install folder. A per-user flatpak lives under
`~/.local/share/flatpak`, owned by your own account, so spicetify can patch
it without `sudo` and without loosening the permissions on any system
directory. A system-wide flatpak install (`/var/lib/flatpak/...`) doesn't
have that property — hence per-user specifically, not just "flatpak".

**If Spotify is already installed system-wide**, `install.sh` leaves it
alone (never uninstalls something you already have) and prints how to
switch instead of doing it for you — also repeated in the end-of-run
Summary. To make the switch by hand:

```bash
flatpak uninstall flathub com.spotify.Client        # the system-wide copy
flatpak install --user flathub com.spotify.Client   # the per-user copy
./install.sh                                        # re-run, or:
spicetify backup apply                              # if spicetify was already set up
```

## Waiting for Spotify's first-run prefs file

spicetify's `prefs_path` (`~/.var/app/com.spotify.Client/config/spotify/prefs`)
is written by Spotify itself on **first launch** — it doesn't exist right
after installing the flatpak, and spicetify's config/apply step needs it to
exist first. `install.sh` handles this automatically rather than asking you
to do it:

- If the prefs file is already there, it skips straight to configuring
  spicetify.
- If it's missing and Spotify isn't running, the installer launches
  `flatpak run com.spotify.Client` itself in the background, waits up to
  20 seconds for the prefs file to appear, then stops that instance
  (`kill`, falling back to `pkill -f com.spotify.Client`) — so it never
  leaves a stray Spotify window open just to finish theming it.
- If it's missing but Spotify is *already* running (you started it
  yourself), the installer never touches your session — it only waits up to
  20 seconds for the prefs file to show up on its own, the same rule this
  installer applies everywhere else to a live process it didn't start.
- If the prefs file still isn't there after the wait either way, the
  config/apply step is skipped with instructions to run it by hand once
  Spotify has had a chance to start:
  ```bash
  ~/.spicetify/spicetify backup apply
  ```

## After a Spotify update

Spotify updates overwrite spicetify's patches. Reapply with:

```bash
~/.spicetify/spicetify backup apply
```

The matugen accent template doesn't need re-rendering for this — only
spicetify's own patch needs reapplying; `theme.js`'s own polling picks the
current accent back up as soon as it's running again.
