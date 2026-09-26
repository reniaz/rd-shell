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

## Wallpaper colours

The settings popup's **Wallpaper colours** toggle (`settings.json`'s
`wallpaperColours`, off by default) changes which matugen scheme dynamic
colour renders with. Off, matugen runs its usual `tonal-spot` scheme, which
invents a secondary/tertiary hue rather than staying inside the wallpaper's
own colour — this is also why a black-and-white wallpaper still gives the
bar a blue accent with the toggle off: matugen can't extract a colour from
an image that has none, so it falls back to its own default blue regardless
of scheme. On, `scripts/matugen-scheme.sh` swaps in matugen's `content`
scheme instead, which keeps the full chroma of the wallpaper's own source
colour and picks an analogous (not complementary) tertiary hue, so the theme
reads as *this wallpaper's* palette rather than Material's reinterpretation
of it — unless the wallpaper is itself achromatic (or near enough that
matugen can't find real chroma in it either), in which case it renders
`monochrome` instead: white/grey/black only, so an accent-less wallpaper
gets an accent-less theme rather than that same invented blue. Same
restart-the-render behaviour as flipping dynamic colour itself.
