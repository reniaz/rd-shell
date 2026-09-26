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
  "focusRing": false
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

There's no UI-sounds toggle any more — the feature (and
`Services/UiSound.qml`) has been removed outright, not just hidden.

Edits to `settings.json` apply live — `Services/Settings.qml` watches the
file and re-runs the affected pass (colour, in `dynamicColour`'s case)
without a restart.
