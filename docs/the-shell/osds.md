# OSDs

On-screen displays — a brief overlay rather than a popup you open, triggered
by the matching key/bind:

- **Keyboard layout** (`KeyboardLayoutOsd.qml`) — `Ctrl+Shift+Space` cycles
  layouts and shows which one is now active. Only relevant when
  `input.kb_layout` in `hypr/hyprland.lua` lists more than one layout.
- **Brightness** (`BrightnessOsd.qml`) — `XF86MonBrightnessUp`/`Down`, backed
  by `brightnessctl`.
- **Volume** (`AudioOsd.qml`) — `XF86AudioRaiseVolume`/`LowerVolume`/`Mute`,
  backed by `wpctl`. Mute uses the same red-slash/spring glyph
  (`MuteGlyph.qml`) as the bar's mic/volume pills.
- **Caps/Num Lock** (`LockKeysOsd.qml`) — flips whenever either lock key is
  pressed, showing which one and whether it's now on or off. Backed by
  `Services/LockKeys.qml`.

`BarOsdWatch.qml` positions these consistently against whatever monitor
triggered them.
