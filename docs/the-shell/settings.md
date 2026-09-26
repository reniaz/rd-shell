# Settings popup & settings.json

The `✦` pill on the left of the bar opens `SettingsPopup.qml`. It holds:

- **Desktop widgets** — on/off switch for the [desktop clock and Spotify
  card](desktop-widgets.md).
- **UI scale** — a slider from `0.85×` to `1.5×`, applied shell-wide.
- **High contrast** — toggle.
- **Visible focus ring** (`FocusRing.qml`) — draws a 2px accent ring around
  whichever control keyboard focus is on right now (a launcher row, a
  toggle, the slider handle, …). Off by default; every focusable control in
  the shell already carries the ring, gated on this one setting.
- **Wallpaper colours** — off by default. On, dynamic colour keeps the
  wallpaper's own colours (matugen's `content` scheme) instead of the usual
  `tonal-spot`, which invents a secondary/tertiary hue — or, for a
  black-and-white wallpaper that has no colour of its own to keep,
  `monochrome` (white/grey accent) instead of matugen's own blue fallback.
  See [Theming](../theming/README.md#wallpaper-colours). Directly under it,
  **Keep app colours** — on by default, and only ever relevant once the
  wallpaper toggle above has actually landed on `monochrome` — keeps nvim and
  bat on their own hued syntax scheme instead of following the wallpaper into
  grey; everything else stays monochrome either way.

Everything the popup can set is backed by a single file,
`settings.json`, next to `shell.qml` in `~/.config/quickshell/rd-shell/` —
written by `Services/Settings.qml`, never committed to the repo. It doesn't
need to exist; every property has its own default:

```json
{
  "dynamicColour": true,
  "sysTab": "cpu",
  "desktopWidgets": true,
  "uiScale": 1.0,
  "highContrast": false,
  "focusRing": false,
  "wallpaperColours": false,
  "keepAppColours": true
}
```

| Key | Default | What it does |
|---|---|---|
| `dynamicColour` | `true` | Whether the bar, semantic pills and Hyprland's window borders follow the wallpaper (matugen) or stay on the static caelus palette. Not exposed in the settings popup — edit the file by hand. See [Theming](../theming/README.md). |
| `sysTab` | `"cpu"` | Which tab the system monitor popup remembers across opens. |
| `desktopWidgets` | `true` | The toggle described above. |
| `uiScale` | `1.0` | The UI scale slider described above. |
| `highContrast` | `false` | The high-contrast toggle described above. |
| `focusRing` | `false` | The visible-focus-ring toggle described above. |
| `wallpaperColours` | `false` | The wallpaper-colours toggle described above; resolved by `scripts/matugen-scheme.sh` into matugen's `content` scheme (`monochrome` for a wallpaper with no real colour) instead of `Config/Caelus.qml`'s fixed `tonal-spot`. |
| `keepAppColours` | `true` | The keep-app-colours toggle described above. No effect unless `wallpaperColours` is on and the wallpaper itself resolved to `monochrome`; when it has, this keeps nvim and bat on a hued scheme while everything else (bar, GTK/Qt/KDE, borders, lock, terminal, btop, yazi, starship) stays grey. Off follows the wallpaper everywhere, nvim and bat included. |

There's no UI-sounds toggle any more — the feature (and
`Services/UiSound.qml`) has been removed outright, not just hidden.

Edits to `settings.json` apply live — `Services/Settings.qml` watches the
file and re-runs the affected pass (colour, in `dynamicColour`'s case)
without a restart.
