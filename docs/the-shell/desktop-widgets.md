# Desktop widgets

`DesktopWidgets.qml` draws these on their own layer, below every window and
above the wallpaper — what you actually see on an empty workspace or through
the gaps between tiles:

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

## Sticky notes (`StickyNote.qml` / `Services/StickyNotes.qml`)

`Super+S` drops a new note at the cursor — but only on an empty workspace;
the bind is a no-op over any window, so it can't paper over what you're
working on. Dark, translucent card (same surface/border treatment as the
Spotify card above), a slight random tilt per note, and a handwritten font
picked at runtime from whatever's installed (Caveat, Kalam, Patrick Hand,
Indie Flower, Comic Neue, Comic Mono, in that order) — falls back to the
shell's own font, italicised, if none of them are.

Tap a note to edit it; clicking away, Escape, or losing focus ends editing,
and an emptied note is deleted rather than left blank. Drag anywhere to
move it, or the bottom-right grip (hover-revealed, like the delete glyph) to
resize between a minimum and half the screen. Notes persist to
`sticky-notes.json` in Quickshell's own state directory and stay pinned to
the monitor they were created on.

## Toggling

The desktop clock and Spotify card are on by default; toggle them off from
the settings popup (`✦` pill) — see [Settings popup](settings.md). Backed by
`Services/Settings.qml`'s `desktopWidgets` property (`settings.json`).
Sticky notes have no such toggle — they're created only by `Super+S`, never
automatically.
