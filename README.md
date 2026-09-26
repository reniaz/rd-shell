<div align="center">

# ✦ rd shell ✦

**A Quickshell bar/desktop shell for Hyprland, plus the author's full rice.**

<sub>bar · notifications · launcher · osd · lockscreen · matugen theming</sub>

![QML](https://img.shields.io/badge/QML-41CD52?style=flat-square&logo=qt&logoColor=white)
![Wayland](https://img.shields.io/badge/Wayland-FFBC00?style=flat-square&logo=wayland&logoColor=black)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

</div>

---

`rd-shell` is a [Quickshell](https://quickshell.outfoxxed.me) (QML) bar built
for a Lua-configured [Hyprland](https://hyprland.org) on Fedora 44. This repo
is the whole rice: the bar, the Hyprland config it was built against
(`hypr/`), app dotfiles wired to [matugen](https://github.com/InioX/matugen)
wallpaper colours (`dotfiles/`), the author's wallpapers, and one installer
(`install.sh`) for a fresh box.

**Stack at a glance:** Hyprland · Quickshell · matugen · ghostty ·
hyprlauncher · fetchit · btop · cava · nvim · yazi · vesktop · spicetify ·
starship.

GitHub: [reniaz/rd-shell](https://github.com/reniaz/rd-shell) ·
**Full docs: [the wiki](docs/README.md)**

## Preview

![edge bar](assets/edge-art.gif)

*The edge bar's hover-revealed DDC brightness/contrast strip — see
[The shell → Edge bar](docs/the-shell/edge-bar.md).*

## What it does

Bar with a workspace/media/system-monitor/clock/Claude/network/notification
pill layout, a QML-native launcher (with an inline `qalc` calculator) plus a
searchable, rebindable keybind overview (`Super+K`), a fullscreen wallpaper
switcher that drives dynamic colour end-to-end (bar, Hyprland borders, GTK,
Qt/KDE, icons, cursor, `bat`, Firefox, starship), grouped notifications with
DND — and a Discord/Vesktop incoming-call banner that shows even under it — a
system monitor popup backed by a persistent Python sampler, a hover-revealed
edge bar for DDC brightness on desktop displays, desktop widgets (a clock, a
Spotify now-playing card, and handwritten-style sticky notes) drawn under
every window, a native lock screen with a `hyprlock` fallback, and
accessibility options (UI scale, high contrast, a visible focus ring).

Full tour: **[The shell](docs/the-shell/README.md)**.

## Install

```bash
git clone https://github.com/reniaz/rd-shell ~/coding/qs-bar
cd ~/coding/qs-bar && ./install.sh        # -y to assume yes to every prompt
```

One installer for both scenarios — safe to re-run, every step checks before
it changes anything:

- **Fresh Fedora + Hyprland box, nothing of this rice yet** → just run it.
  See [Fresh install](docs/installation/fresh-install.md).
- **You already have your own hypr/ghostty/nvim/etc. configs** → run it the
  same way; nothing of yours is silently deleted, anything it would replace
  is moved to `<path>.bak-YYYYmmdd-HHMMSS` first. See [Installing over an
  existing config](docs/installation/existing-config.md).

Full walkthrough, requirements, updating and uninstalling: **[Installation](docs/installation/README.md)**.

## Keybinds

`Super+K` opens a searchable overview of every bind, live from the running
compositor. Full table, generated from `hypr/hyprland.lua`: **[Keybinds](docs/keybinds.md)**.

## Wiki

| | |
|---|---|
| [Installation](docs/installation/README.md) | Requirements, both install scenarios, what `install.sh` does step by step, updating, uninstalling |
| [The shell](docs/the-shell/README.md) | Bar, launcher, popups, notifications, OSDs, edge bar, desktop widgets, Claude panel, settings |
| [Keybinds](docs/keybinds.md) | Full table, source of truth `hypr/hyprland.lua` |
| [Theming](docs/theming/README.md) | The matugen pipeline, the wallpaper switcher |
| [Dotfiles](docs/dotfiles/README.md) | Hyprland, ghostty, nvim, btop, cava, yazi, bat, fetchit, spicetify, vesktop, GTK/Qt/KDE, cursor/icons/fonts, Firefox |
| [Troubleshooting](docs/troubleshooting.md) | Symptom → cause → fix, plus reading the shell's own log |

## Credits & licences

rd shell's own code and configs are MIT licensed (`LICENSE`). Everything
below keeps its own licence.

- Built with [Quickshell](https://quickshell.outfoxxed.me)
- **caelusevka** — custom [Iosevka](https://github.com/be5invis/Iosevka)
  build, bundled under `assets/fonts/`; SIL OFL 1.1 (`assets/fonts/OFL.txt`)
- **Material Symbols Rounded** — downloaded by `install.sh` from
  [google/material-design-icons](https://github.com/google/material-design-icons),
  Apache 2.0
- **Wallpapers** — cloned from
  [The-LainOS-Project/LainOS-wallpapers](https://github.com/The-LainOS-Project/LainOS-wallpapers);
  the extras in `wallpapers/` belong to their original artists and are not
  covered by the MIT licence
- **fetchit** — [codeberg.org/nzuum/fetchit](https://codeberg.org/nzuum/fetchit)
- **matugen** — [InioX/matugen](https://github.com/InioX/matugen), the
  dynamic-colour pipeline; palette base from
  [system24](https://github.com/refact0r/system24)'s *caelus* theme

---

<div align="center">
<sub>MIT licensed · built with Quickshell</sub>
</div>
