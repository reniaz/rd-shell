# Dotfiles

Everything under `hypr/` and `dotfiles/` (plus `firefox/`) is a real config
copied from the machine this rice was built on, linked into place by
`install.sh` — see [Installing over an existing
config](../installation/existing-config.md) for exactly how, and what gets
backed up.

| App | Repo path | Linked to |
|---|---|---|
| [Hyprland](hyprland.md) | `hypr/*.lua`, `hypr/*.conf` | `~/.config/hypr/` |
| [matugen (config reference)](matugen.md) | `dotfiles/matugen/`, `matugen/bar.toml` | `~/.config/matugen/config.toml` |
| [ghostty](ghostty.md) | `hypr/dotfiles/ghostty/` | `~/.config/ghostty` (whole directory) |
| [nvim](nvim.md) | `dotfiles/nvim/` (`init.lua`, `lua/{config,keymaps,commands,utils,matugen_watch}.lua`, `lazy-lock.json`, `matugen/`) | `~/.config/nvim/`, per file |
| [btop](btop.md) | `dotfiles/btop/` | `~/.config/btop/` (copy, not symlink — see the page) |
| [cava](cava.md) | `dotfiles/cava/` | `~/.config/cava/` (copy, not symlink — see the page) |
| [yazi](yazi.md) | `dotfiles/yazi/` | `~/.config/yazi/` |
| [bat](bat.md) | `dotfiles/bat/` | `~/.config/bat/` |
| [fetchit](fetchit.md) | `dotfiles/fetchit/` | `~/.config/fetchit/` |
| [spicetify](spicetify.md) | `dotfiles/spicetify/` | `~/.config/spicetify/` |
| [starship](starship.md) | `dotfiles/matugen/templates/starship.toml` | `~/.config/starship.toml` (matugen render output) |
| [vesktop](vesktop.md) | `dotfiles/vesktop/` | `~/.config/vesktop/` |
| [GTK / Qt / KDE](gtk-qt-kde.md) | — (written by `install.sh`, not linked) | `~/.config/gtk-{3,4}.0/`, `kdeglobals`, `kcminputrc` |
| [Cursor, icons & fonts](cursor-icons-fonts.md) | `assets/fonts/`, `assets/fontconfig/` | `~/.local/share/fonts/`, `~/.local/share/icons/`, `~/.config/fontconfig/conf.d/` |
| [Firefox](firefox.md) | `firefox/` | `<profile>/chrome/rd-shell` |

The pipeline that drives every one of the "follows the wallpaper" cells
above is covered conceptually in [Theming → The matugen
pipeline](../theming/matugen-pipeline.md), and as a full config reference
(every template's exact paths, the harmonized ANSI colours, how to add your
own) in [matugen](matugen.md) above.

{% hint style="info" %}
matugen aborts its whole render on the first missing template `input_path`,
so every file below ships in the repo even if you don't have the matching
app installed — `install.sh` links them regardless.
{% endhint %}
