# Theming

`Config/Colors.qml` is the single source of the bar's colours — everything
reads from it and it hot-reloads on save. Its static palette is derived from
the [system24](https://github.com/refact0r/system24) *caelus* theme, accent
`#b86e38`; `templateColor1`…`templateColor12` hold the rest of the caelus
palette, unassigned and ready to name as new widgets need them.

The bar follows the wallpaper **by default**: every wallpaper switch runs
[matugen](https://github.com/InioX/matugen) and `Config/Colors.qml` reads its
palette instead of the fixed caelus theme. This is what "dynamic colour"
means throughout this wiki and the repo.

- [The matugen pipeline](matugen-pipeline.md) — how one wallpaper switch
  reaches the bar, Hyprland's window borders, GTK, Qt/KDE, icons, cursor,
  `bat`, and Firefox.
- [Wallpaper switcher](wallpaper-switcher.md) — the `Ctrl+Alt+F` UI and
  `scripts/wallpaper-apply.sh`, the script that does the actual rendering.

## Toggling dynamic colour

The switch lives in `settings.json` next to `shell.qml`, written by
`Services/Settings.qml`:

```json
{ "dynamicColour": false }
```

`false` pins the static caelus palette; `true` (or no file at all) is dynamic
colour. There's no toggle for this in the settings popup — edit the file by
hand. The change applies live: `Services/Settings.qml` watches the file and
re-runs the colour pass immediately.

One switch, three surfaces read it: the bar, the semantic pills, and
Hyprland's window borders. Borders are applied with `hyprctl eval` (`hyprctl
keyword` doesn't work against a Lua config), so they only pick up a flip of
this switch on the next wallpaper change or Hyprland login — not the instant
you edit the file.

| | dynamic mode |
|---|---|
| surfaces, accent, label text, island edge, network/keyboard/media/notification pills | matugen roles outright |
| volume (green), mic and power (red), `ok`/`warn`/`error`, the 12 chart slots | hue kept, saturation/brightness borrowed |
