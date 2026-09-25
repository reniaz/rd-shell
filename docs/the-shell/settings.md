# Settings popup & settings.json

The `✦` pill on the left of the bar opens `SettingsPopup.qml`. Currently it
holds one toggle:

- **Desktop widgets** — on/off switch for the [desktop clock and Spotify
  card](desktop-widgets.md).

Everything the popup can set is backed by a single file,
`settings.json`, next to `shell.qml` in `~/.config/quickshell/rd-shell/` —
written by `Services/Settings.qml`, never committed to the repo. It doesn't
need to exist; every property has its own default:

```json
{
  "dynamicColour": true,
  "sysTab": "cpu",
  "desktopWidgets": true
}
```

| Key | Default | What it does |
|---|---|---|
| `dynamicColour` | `true` | Whether the bar, semantic pills and Hyprland's window borders follow the wallpaper (matugen) or stay on the static caelus palette. Not exposed in the settings popup — edit the file by hand. See [Theming](../theming/README.md). |
| `sysTab` | `"cpu"` | Which tab the system monitor popup remembers across opens. |
| `desktopWidgets` | `true` | The toggle described above. |

Edits to `settings.json` apply live — `Services/Settings.qml` watches the
file and re-runs the affected pass (colour, in `dynamicColour`'s case)
without a restart.
