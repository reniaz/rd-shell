<div align="center">

# ✦ rd shell ✦

**A personal [Quickshell](https://quickshell.outfoxxed.me) configuration.**

<sub>bar · notifications · launcher · osd · lockscreen</sub>

![QML](https://img.shields.io/badge/QML-41CD52?style=flat-square&logo=qt&logoColor=white)
![Wayland](https://img.shields.io/badge/Wayland-FFBC00?style=flat-square&logo=wayland&logoColor=black)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

<img src="assets/preview.png" alt="preview" width="90%">

</div>

---

## Features

| | |
|---|---|
| **Bar** | workspaces, window title, tray, clock, battery |
| **Launcher** | fuzzy app search, math, actions |
| **Notifications** | grouped popups + history center |
| **OSD** | volume / brightness / mic overlays |
| **Lock** | wallpaper blur, fprint + password |
| **Theming** | one color file, live reload |

## Requirements

- [`quickshell`](https://quickshell.outfoxxed.me) (git)
- Qt 6.8+ · `qt6-declarative`, `qt6-5compat`
- A Wayland compositor — tested on **Hyprland** / **niri**
- Optional: `pipewire`, `networkmanager`, `brightnessctl`, `cava`

## Install

```bash
git clone https://github.com/reniaz/rd-shell ~/.config/quickshell/rd-shell
qs -c rd-shell
```

Autostart with Hyprland:

```ini
exec-once = qs -c rd-shell

# or

hl.dsp.exec_cmd("qs -c rd-shell")
```

## Structure

```
shell/
├── shell.qml          # entry point
├── modules/
│   ├── bar/
│   ├── launcher/
│   ├── notifications/
│   └── lock/
├── services/          # singletons: audio, network, battery…
├── widgets/           # shared components
└── config/
    ├── Colors.qml     # palette
    └── Settings.qml   # sizes, fonts, toggles
```

## Theming

Edit `config/Colors.qml` — everything reads from it and hot-reloads on save.

```qml
readonly property color bg:     "#11111b"
readonly property color fg:     "#cdd6f4"
readonly property color accent: "#89b4fa"
```

## Keybinds

| Key | Action |
|---|---|
| <kbd>Super</kbd> | Launcher |
| <kbd>Super</kbd> + <kbd>N</kbd> | Notification center |
| <kbd>Super</kbd> + <kbd>L</kbd> | Lock |

---

<div align="center">
<sub>Built with Quickshell · MIT</sub>
</div>
