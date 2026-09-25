# Cursor, icons & fonts

None of these are per-app dotfiles under `dotfiles/` — they're system-level
assets `install.sh` fetches or bundles, then points GTK/Qt/Hyprland at.

## Cursor: Bibata-Original-Classic

No Fedora package. Downloaded from the latest
[ful1e5/Bibata_Cursor](https://github.com/ful1e5/Bibata_Cursor) release into
`~/.local/share/icons/Bibata-Original-Classic`. `hyprland.lua` runs
`hyprctl setcursor Bibata-Original-Classic 36` at startup; GTK and Qt/KDE are
pointed at the same theme+size by `install.sh` (see [GTK / Qt /
KDE](gtk-qt-kde.md)).

## Icons: Papirus-Dark

No Fedora package either. Installed **user-level**
(`DESTDIR=~/.local/share/icons`, no sudo — deliberately not the project's own
default of a root-owned system-wide install) from
[PapirusDevelopmentTeam/papirus-icon-theme](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)'s
own install script. `papirus-folders` (a single self-contained bash script
from [its own repo](https://github.com/PapirusDevelopmentTeam/papirus-folders))
is installed to `~/.local/bin/papirus-folders`; `scripts/papirus-accent.sh`
drives it from matugen's `[templates.papirus]` `post_hook` on every wallpaper
switch to recolour Papirus-Dark's folder icons to match the accent. Both
being sudo-free end to end is deliberate: the recolour runs unattended from a
wallpaper switch, where a stalled `sudo` prompt would just hang it.

## Fonts

- **Material Symbols Rounded** — downloaded on demand from
  [google/material-design-icons](https://github.com/google/material-design-icons)
  into `~/.local/share/fonts`. `assets/fontconfig/99-rd-shell-symbols.conf`
  is linked to `~/.config/fontconfig/conf.d/` *before* the font check, to
  drop any app's own subset of the family that would otherwise outrank the
  full font and turn every bar icon into its literal ligature name (e.g.
  `queue_music`).
- **caelusevka** — a custom [Iosevka](https://github.com/be5invis/Iosevka)
  build used for all label text, bundled directly under `assets/fonts/`
  (SIL OFL 1.1, `assets/fonts/OFL.txt`) since it isn't on any distro repo.
  Copied into `~/.local/share/fonts` by `install.sh`.

Verifying either font resolves correctly:

```bash
fc-match -f '%{family}' 'Material Symbols Rounded'
fc-match -f '%{family}' 'caelusevka'
```

See [Troubleshooting](../troubleshooting.md) for what a missing or
shadowed font looks like on the bar.
