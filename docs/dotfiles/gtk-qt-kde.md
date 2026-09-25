# GTK / Qt / KDE

Unlike the rest of `dotfiles/`, GTK and KDE theming isn't a linked file —
`install.sh` writes/edits your actual config in place, and matugen keeps the
colours current afterwards.

## GTK3 / GTK4 / libadwaita

For each of `~/.config/gtk-3.0` and `~/.config/gtk-4.0`, `install.sh`:

- writes/updates `settings.ini`'s `gtk-theme-name` (`adw-gtk3-dark`),
  `gtk-icon-theme-name` (`Papirus-Dark`), and cursor theme/size
  (`Bibata-Original-Classic`, 36) — existing keys are updated in place,
  missing ones appended.
- appends one `@import url("file://$HOME/.cache/rd-shell/gtk-colors.css");`
  line to `gtk.css` if it's not already there, self-healing across whatever
  else (e.g. KDE's `kde-gtk-config` sync) regenerates that file on its own
  triggers.
- sets the matching `gsettings` keys (`org.gnome.desktop.interface`
  `gtk-theme`/`icon-theme`/`cursor-theme`/`cursor-size`/`color-scheme`).

`gtk-colors.css` itself is a matugen template
(`dotfiles/matugen/templates/gtk-colors.css`, `[templates.gtk]`) rendered on
every wallpaper switch — but GTK doesn't watch `gtk.css`, so this only takes
effect on an app's *next* launch, never live.

`adw-gtk3-theme` is a plain Fedora package (no COPR needed).

## Qt / KDE

- **Icon theme** — `kdeglobals`' `Icons`/`Theme` key set to `Papirus-Dark`
  via `kwriteconfig6 --notify`, which broadcasts the same change signal a
  real KCM apply would, so running Qt/KDE apps pick it up without a restart.
- **Cursor** — `plasma-apply-cursortheme` sets `Bibata-Original-Classic`,
  then `kcminputrc`'s `cursorSize` is force-written to 36 with
  `kwriteconfig6` afterward, since `plasma-apply-cursortheme --size 36`
  snaps to the theme's nearest pre-rendered size (32) rather than 36 —
  Bibata is scalable and renders fine at 36 regardless.
- **Colour scheme** — matugen's `[templates.kde]` template renders a KDE
  colour scheme to `~/.local/share/color-schemes/Matugen.colors` on every
  wallpaper switch, and its `post_hook` applies it with
  `plasma-apply-colorscheme`, alternating between the names `Matugen` and
  `Matugen2` because that command refuses to re-apply a scheme that's
  already active. `install.sh` only handles the very first apply, before any
  wallpaper switch has happened.
- **Qt theme integration** — `plasma-integration` (a plain package,
  required) is what makes `QT_QPA_PLATFORMTHEME=kde` (set in `hyprland.lua`)
  actually apply the system theme to Qt apps; without it Qt apps ignore
  `kdeglobals` entirely.

`install.sh` only wires the **dark** palette end to end — switching to light
mode is a manual `kcmshell6 kcm_style` / `kcm_colors` change afterward.
