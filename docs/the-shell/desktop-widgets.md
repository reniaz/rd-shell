# Desktop widgets

`DesktopWidgets.qml` draws two things on their own layer, below every window
and above the wallpaper — what you actually see on an empty workspace or
through the gaps between tiles:

## Desktop clock (`DesktopClock.qml`)

A giant clock in the top-right corner.

## Spotify card (`DesktopMedia.qml` / `DesktopTransport.qml`)

A now-playing card, directly under the clock, for **Spotify only** — Firefox
or any other player never makes it appear.

- **Idle**: just a `cava` bar visualizer with no background.
- **Hover**: a see-through card grows out of it with an accent border — art
  ringed by a radial visualizer, a scrolling title, the artist with any
  featured artists (full Spotify credits; two or more fade through one at a
  time), a seekable progress bar, shuffle / previous / play-pause
  / next / loop, and a volume control that grows across that row and scrubs
  from wherever you grab it.

## Toggling

On by default. Toggle it off from the settings popup (`✦` pill) — see
[Settings popup](settings.md). Backed by `Services/Settings.qml`'s
`desktopWidgets` property (`settings.json`).
