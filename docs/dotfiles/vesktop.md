# vesktop

`dotfiles/vesktop/`, linked to `~/.config/vesktop/`:

| File | What it restyles |
|---|---|
| `themes/system24-caelus.theme.css` | the static base theme — the same [system24](https://github.com/refact0r/system24) *caelus* palette the rest of this rice is built on, applied to Discord's whole UI |
| `themes/matugen/caelus-accent.css` | the matugen template — just the accent colour, layered on top of the base theme |

## The matugen wiring

- Template: `dotfiles/vesktop/themes/matugen/caelus-accent.css` →
  `[templates.vesktop]` in `dotfiles/matugen/config.toml` → rendered to
  `~/.config/vesktop/themes/caelus-accent.theme.css` on every wallpaper
  switch.
- Rendered as a **separate Vencord theme file**, enabled alongside
  `system24-caelus` rather than `@import`-ed from inside it: Vencord only
  cache-busts the themes it loads directly as top-level entries, so a nested
  `@import` would keep showing the *previous* wallpaper's colour until a
  full Vesktop restart. Vencord watches its themes folder for changes, so a
  render straight to a file it already has loaded recolours a running
  client immediately — no restart, no manual reload.

## Turning both themes on

Vencord (the mod Vesktop bundles) keeps its enabled theme list in
`~/.config/vesktop/settings/settings.json`, under `enabledThemes` — on a
correctly set-up install that array holds both filenames:

```json
"enabledThemes": ["system24-caelus.theme.css", "caelus-accent.theme.css"]
```

`install.sh` does **not** write this file or flip this setting — Vesktop
itself isn't installed by the installer (see below), and its settings live
entirely inside Vesktop's own config, which this rice doesn't touch. Turning
both themes on is a one-time manual step after installing Vesktop:

1. Open Vesktop → Settings → Vencord → Themes.
2. Enable **system24-caelus** and **caelus-accent** (both need to be on —
   the second is accent-only and does nothing without the base theme under
   it).

Editing `enabledThemes` directly in `settings.json` works too, but that file
also holds Vesktop's own account/session state — safer to use the in-app
toggle than to hand-edit the file.

## Installing Vesktop itself

`vesktop` is autostarted from `hyprland.lua` if present, but **not**
installed by `install.sh` — install it yourself
(`flatpak install flathub dev.vencord.Vesktop`); the matugen templates above
are already linked and pick up the current wallpaper as soon as both themes
are enabled.
