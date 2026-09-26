import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The desktop layer proper: a giant clock, the now-playing card, and (idea
// 40) sticky notes -- what caelestia-shell calls its desktop widgets, seen on
// an empty workspace or through the gaps between tiled windows. Sits above
// Wallpaper's own Background layer and below every real window
// (WlrLayer.Bottom is the layer between the two), so it never competes with
// anything actually being worked in. One per screen, the same idiom
// Wallpaper, BarWindow and EdgeBar already use from shell.qml.
PanelWindow {
    id: root

    required property var modelData

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    // OnDemand only while a note on *this* screen actually holds the caret
    // -- the same "ask for focus only while something here wants it" idiom
    // BarWindow.qml already uses for `overlays.anyPopupOpen`. Scoped to this
    // screen specifically, not to StickyNotes.editingId being merely
    // non-empty: that id is one shared value across every monitor's own
    // DesktopWidgets instance, and asking every screen's surface for
    // keyboard focus at once over a note that lives on only one of them
    // would leave the compositor to guess which surface actually wants the
    // keys. None the rest of the time, same as before -- this layer never
    // holds focus it has no present use for.
    WlrLayershell.keyboardFocus: root._editingHere
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-desktop"
    color: "transparent"

    // The whole window, not just its content -- an invisible-but-mapped
    // surface would still be a full-screen layer the compositor keeps
    // around and asks for input, for widgets nobody can see.
    visible: Settings.desktopWidgets

    // This screen's own notes, filtered out of the whole shared list. Also
    // what decides `_editingHere` above.
    readonly property var _screenNotes: StickyNotes.forScreen(modelData.name)
    readonly property bool _editingHere: StickyNotes.editingId !== ""
        && root._screenNotes.some(n => n.id === StickyNotes.editingId)

    // Used to be an empty region except for the now-playing card (DesktopMedia's
    // own `shown`), so the clock and the rest of the desktop fell straight
    // through to whatever was underneath -- Wallpaper.qml's own permanently
    // empty mask, or nothing at all. A sticky note can now sit (and be
    // dragged, tapped, typed into) anywhere on this whole surface, and a
    // click outside every note needs to reach `desktopArea` below to end
    // whichever one is being edited, so this is the full surface rather than
    // just the media card's own bounds. That widening is safe on both counts
    // the old comment worried about: a real window is always composited
    // *above* a WlrLayer.Bottom surface regardless of what this surface's
    // own input region claims, so a window never loses a click to it either
    // way; and Wallpaper.qml's own mask is permanently empty (see its
    // header), so it never had a click of its own to lose here either. What
    // this surface gains is only ever a click that had nothing else already
    // under it.
    mask: Region { x: 0; y: 0; width: root.width; height: root.height }

    // ── click-outside ends editing ──────────────────────────────
    // Declared first so every real widget below (clock, media, notes) paints
    // -- and takes input -- on top of it; this only ever sees a click that
    // nothing else already claimed. Notes are created only via
    // Services/StickyNotes.qml's `create()` (SUPER+S) now, never by clicking
    // the desktop -- that gesture kept firing by accident, so there is
    // nothing left here to make one.
    MouseArea {
        id: desktopArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton

        // Reaching this handler at all already means the click landed on
        // neither a note (its own TapHandler would have claimed it) nor the
        // text being edited (TextEdit claims its own clicks while
        // `enabled`) -- so any note still mid-edit, wherever its screen, is
        // done.
        onClicked: StickyNotes.editingId = ""
    }

    // Top-right corner, right-aligned, clear of the bar strip above it.
    // EdgeBar puts its hover strip on whichever side is this screen's true
    // outer edge (left *or* right, decided by geometry, and only 6px + a 48px
    // card even at its widest) -- 72px clears that either way without having
    // to ask EdgeBar which side it picked for this particular screen.
    ColumnLayout {
        id: widgets

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Caelus.barHeight + 40
        anchors.rightMargin: 72
        spacing: Caelus.spaceEdge

        DesktopClock {}

        DesktopMedia {
            id: media
            Layout.alignment: Qt.AlignRight
        }
    }

    // ── sticky notes (idea 40) ───────────────────────────────────
    // ScriptModel keyed on `objectProp: "id"` rather than a plain
    // `model: root._screenNotes`: every edit to a note's text/position/
    // colour replaces its entry in Services/StickyNotes.qml's `list` with a
    // fresh object (see that file's `update()`), and a plain array model
    // would read that as "a different item" and tear down and rebuild the
    // delegate -- dropping the caret and every keystroke typed right after.
    // Keying on `id` instead tells Repeater this is the *same* logical note
    // whatever else changed on it, so the one StickyNote instance survives
    // for as long as the note itself does.
    Repeater {
        model: ScriptModel {
            values: root._screenNotes
            objectProp: "id"
        }

        delegate: StickyNote {
            screenSize: Qt.size(root.width, root.height)
        }
    }
}
