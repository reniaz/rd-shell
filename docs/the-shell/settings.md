# Settings

There are two ways into settings, and they end up in the same place:

- **The popup** — the `✦` pill on the left of the bar opens
  `SettingsPopup.qml`, a short list of the handful of things worth a single
  click (below). Its **All settings** row opens the window.
- **The window** — `Super+I`, or `qs ipc -c rd-shell call settings toggle`,
  opens `SettingsWindow.qml`: a real floating window (not a layer-shell
  panel like everything else in this shell) with a nav rail on the left —
  Appearance, Bar, Desktop, Accessibility, Keybinds, About — and that page's
  cards on the right. It's also in the launcher (`Super+Space`, type
  "settings"), and Hyprland floats and centers it at 960×640 via a
  `settings-window` rule in `hyprland.lua` matched on its window class
  (`org.quickshell`, Quickshell's one and only real xdg-toplevel — everything
  else is layer-shell and never shows up in `hyprctl clients`) and title
  (`rd-shell settings`).

  `qs ipc -c rd-shell call settings open <page>` jumps straight to a page
  (`look`, `bar`, `desktop`, `access`, `keys`, `about`); the last page open
  is remembered (`settingsPage` in `settings.json`, below). Closing the
  window — `Escape`, the titlebar, `Super+Q`, whatever the compositor uses —
  is a real window close, caught via `FloatingWindow`'s own `closed` signal,
  so `qs ipc -c rd-shell call settings toggle` right after always reopens it
  rather than needing a second toggle to "catch up."

  Inside the window: `Escape` closes it, `Ctrl+Tab` / `Ctrl+Shift+Tab` cycle
  pages, `Ctrl+1`…`Ctrl+6` jump straight to a rail entry by position.

## The popup

`SettingsPopup.qml` holds:

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

## Accessibility page

The window's Accessibility page carries the popup's own UI scale/high
contrast/focus ring (above) plus one more card, **Animation** — Hyprland's
whole-desktop motion, not just this shell's own:

- **Motion preset** — a four-way choice (Snappy, Smooth, Bouncy, Minimal)
  applied live via `hyprctl eval`, no reload needed. **Minimal** is this
  page's actual reduced-motion option: fades only, no sliding or popping.
  **Smooth** is the default and reproduces this rice's original, hand-tuned
  curves and speeds exactly. See [Hyprland →
  animation-presets.lua](../dotfiles/hyprland.md#animation-presets) for how
  the choice survives a reload.
- **Animated switcher** button — opens the same `Ctrl+Alt+P` coverflow
  (below) without leaving the keyboard for the mouse.

Like `barStyle`, the chosen preset (`animPreset` in `settings.json`,
`"snappy"` / `"smooth"` / `"bouncy"` / `"minimal"`) isn't in the table below —
see this section instead.

## Desktop page

Round 5 (calendar-reminders-rework) adds a Calendar card to the window's
Desktop page, next to the desktop-widgets/clipboard-ripple toggles — both
read straight by `CalendarGrid.qml`, the grid the dashboard's calendar pane
builds on (`DashCalendarPane.qml`, see [Popups → Dashboard](popups.md)):

- **Week starts on** — `"monday"` (default, matching the grid's original
  hand-written Monday-first layout) or `"sunday"`.
- **Week numbers** — off by default; on, an ISO-8601 week number is printed
  beside each row of the grid, numbered the same way regardless of which day
  the row itself starts on.

Like `animPreset` above, `weekStart`/`weekNumbers` aren't in the table below
— they're a page of their own now, not a predates-the-window key.

Everything the popup and the window can set is backed by a single file,
`settings.json`, next to `shell.qml` in `~/.config/quickshell/rd-shell/` —
written by `Services/Settings.qml`, never committed to the repo. It doesn't
need to exist; every property has its own default. The window's pages add
their own keys to the same file (a bar style, a bluetooth-pill toggle, and
so on) — see each page's own doc rather than this list, which only tracks
what predates the window plus the one key the window itself owns:

```json
{
  "dynamicColour": true,
  "sysTab": "cpu",
  "settingsPage": "look",
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
| `settingsPage` | `"look"` | Which rail page the settings window remembers across opens/closes. |
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
