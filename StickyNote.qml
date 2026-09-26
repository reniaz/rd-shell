import QtQuick
import qs.Config
import qs.Services

// One sticky note (idea 40). One look for every note -- dark and translucent,
// the desktop partly showing through -- draggable, resizable, tap-to-edit,
// with hover-only delete and resize glyphs. Created only via
// Services/StickyNotes.qml's `create()` (bound to SUPER+S) and otherwise
// fully data-driven off that service, which owns the list and the
// persistence. This file only knows how one note looks and behaves.
//
// Surface and border are copied exactly from DesktopMedia.qml's own card --
// same radius token, same Colors.surface-at-bodyAlpha fill, same border
// idiom (transparent at rest, the shell's accent while "open" -- here, while
// editing) -- so a note reads as one more piece of this desktop's own chrome
// rather than a shape of its own. No shadow, no blur layer: DesktopMedia's
// card has neither (its own header explains why -- no blur layer rule
// behind it the way the popups get, translucency alone does the work), and
// that choice is deliberate, so this respects it rather than adding either
// back in.
Item {
    id: root

    // The note record: { id, screen, x, y, w, h, text, rotation }. Handed
    // over by Repeater as the row for this id -- DesktopWidgets.qml pairs
    // that Repeater with a ScriptModel keyed on `objectProp: "id"`, which is
    // what lets this same delegate live through every edit to text/x/y/w/h
    // instead of being torn down and rebuilt on each one (a rebuild mid-edit
    // would drop the caret and the keystrokes typed right after). `w`/`h`
    // are absent on a note that has never been resized (see `width`/`height`
    // below); an older note on disk may also still carry a `color` field
    // from before every note had one look -- nothing here reads it.
    required property var modelData
    readonly property var note: modelData

    // This screen's own size, in local (window) coordinates -- handed over
    // rather than read off `parent`, since a Repeater delegate is not
    // guaranteed a `parent` with the geometry meant here.
    required property size screenSize

    readonly property bool editing: StickyNotes.editingId === note.id

    // Resizable: a note with no `w`/`h` field (every note before this
    // feature, and every brand new one) falls back to the shared default;
    // `resizeArea` below writes `w`/`h` back once the user actually drags
    // the corner. Clamped the same way on every read, whether the value
    // came from disk or from a drag just now, so a stale/hand-edited size in
    // the JSON can never render a note off the note-min..half-screen range.
    readonly property real _minW: StickyNotes.noteMinWidth
    readonly property real _minH: StickyNotes.noteMinHeight
    // Bounded both by "half the screen" and by "however much room is left
    // between this note's own left/top edge and that edge of the screen" --
    // the second bound is what keeps a resize from ever pushing the note's
    // far corner past the screen, without having to re-clamp x/y afterwards.
    readonly property real _maxW: Math.max(root._minW,
        Math.min(root.screenSize.width * 0.5, root.screenSize.width - root.x))
    readonly property real _maxH: Math.max(root._minH,
        Math.min(root.screenSize.height * 0.5, root.screenSize.height - root.y))

    width: Math.min(Math.max(note.w ?? StickyNotes.noteWidth, root._minW), root._maxW)
    height: Math.min(Math.max(note.h ?? StickyNotes.noteHeight, root._minH), root._maxH)

    // A fixed tilt per note (rolled once in StickyNotes.add and kept in the
    // record forever after), straightened out the moment it is actually
    // being read or written -- a paragraph typed on a permanent 3-degree
    // slant is the one place the handwritten look should get out of the way.
    rotation: root.editing ? 0 : note.rotation
    transformOrigin: Item.Center

    Behavior on rotation {
        NumberAnimation { duration: Motion.fast; easing.type: Motion.standard }
    }

    // Clamped to the screen's *current* bounds, not to whatever they were
    // the day this note was dropped on disk -- see StickyNotes.qml's own
    // header for why that clamp lives here and not there.
    readonly property real _maxX: Math.max(0, root.screenSize.width - root.width)
    readonly property real _maxY: Math.max(0, root.screenSize.height - root.height)
    x: Math.min(Math.max(note.x, 0), root._maxX)
    y: Math.min(Math.max(note.y, 0), root._maxY)

    // The note being edited draws over every other note near it.
    z: root.editing ? 10 : 1

    // Whichever note this was, "not editing any more" is exactly the point
    // to flush the caret's last position -- covers Escape, clicking another
    // note (StickyNotes.editingId just changes to that one), the desktop's
    // own click-outside handler in DesktopWidgets.qml, and delete, all in
    // one place instead of four.
    //
    // A note left with nothing in it goes away here too, so a stray SUPER+S
    // never leaves a blank card behind.
    //
    // Both writes are deferred: changing `StickyNotes.list` from inside this
    // handler re-evaluates `editing` (it reads the same singleton) while it
    // is still changing, which Qt reports as a binding loop.
    onEditingChanged: if (!root.editing) {
        saveDebounce.stop();
        const id = note.id, text = body.text;
        if (text.trim() === "") Qt.callLater(StickyNotes.remove, id);
        else if (text !== note.text) Qt.callLater(StickyNotes.update, id, { text: text });
    }

    // ── drag ─────────────────────────────────────────────────
    // Off while editing: the card holds still so a drag begun by selecting
    // text never also drags the note, and the tap that starts an edit never
    // has to race a drag recognizer over the same pixels.
    DragHandler {
        target: root
        enabled: !root.editing
        onActiveChanged: if (!active) StickyNotes.update(note.id, { x: root.x, y: root.y });
    }

    // ── tap to edit ────────────────────────────────────────────
    TapHandler {
        enabled: !root.editing
        onTapped: {
            StickyNotes.editingId = note.id;
            body.text = note.text;
            body.forceActiveFocus();
        }
    }

    // ── card ───────────────────────────────────────────────────
    Rectangle {
        id: card

        anchors.fill: parent
        radius: Caelus.radiusIsland
        // Colors.surface at the same alpha DesktopMedia's own card uses --
        // see that file's `bodyAlpha` for why this number, not a rounder
        // one, is the one that reads as "translucent slab" rather than
        // either "opaque card" or "barely there" over a bright wallpaper.
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.4)
        border.width: Caelus.borderWidth
        // Transparent at rest, the shell's own accent while this note holds
        // the caret -- the exact idiom DesktopMedia's card border uses for
        // idle vs. expanded, just keyed on `editing` instead of `_expanded`.
        border.color: root.editing ? Colors.popupAccent : "transparent"
        clip: true

        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        TextEdit {
            id: body

            anchors.fill: parent
            anchors.margins: Caelus.spaceWide
            wrapMode: TextEdit.Wrap
            text: note.text
            color: Colors.fg
            font.family: StickyNotes.noteFont
            font.italic: StickyNotes.noteFontItalic
            font.pixelSize: StickyNotes.noteFontSize
            // Fully inert while not editing: `enabled: false` is the one
            // property guaranteed to remove an Item from hit-testing
            // outright, rather than leaning on readOnly/selectByMouse
            // interactions that would otherwise still contend with the
            // TapHandler/DragHandler above over the same clicks.
            enabled: root.editing
            readOnly: !root.editing
            selectByMouse: root.editing
            activeFocusOnPress: root.editing

            onTextChanged: if (root.editing) saveDebounce.restart();

            Keys.onEscapePressed: StickyNotes.editingId = "";
            // Keyboard focus leaving for the bar, a popup or a window ends
            // the edit too, rather than leaving the desktop layer holding
            // OnDemand focus for a note nobody is typing into.
            onActiveFocusChanged: if (!activeFocus && root.editing) StickyNotes.editingId = "";
        }

        // ── delete ───────────────────────────────────────────
        Text {
            id: deleteGlyph

            text: "close"
            color: deleteArea.containsMouse ? Colors.error : Qt.rgba(1, 1, 1, 0.45)
            font.family: Caelus.symbolFamily
            font.pixelSize: 15
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            opacity: hover.hovered ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

            MouseArea {
                id: deleteArea

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: StickyNotes.remove(note.id)
            }
        }

        // ── resize ───────────────────────────────────────────
        // Bottom-right grip, hover-revealed like the delete glyph and live
        // whether or not the note is being edited -- resizing is not a
        // text-editing action. Declared after `body` (and after the delete
        // glyph) so it sits on top of both for hit-testing: QtQuick tests a
        // parent's children back-to-front, so the last-declared sibling
        // claims an overlapping pixel first -- the same reason the delete
        // glyph's own corner already works over the TextEdit beneath it,
        // here reused so the grip wins over both the TextEdit's own drag-to-
        // select and `root`'s own move DragHandler beneath everything.
        Text {
            id: resizeGrip

            text: "open_in_full"
            color: resizeArea.containsMouse ? Colors.popupAccent : Qt.rgba(1, 1, 1, 0.45)
            font.family: Caelus.symbolFamily
            font.pixelSize: 13
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 4
            opacity: hover.hovered ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

            MouseArea {
                id: resizeArea

                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.SizeFDiagCursor

                // `mapToItem(root, ...)` lands the mouse position in root's
                // own local, unrotated content space -- since resizing never
                // moves root's own (0,0) origin (only x/y do that), that
                // mapped point's x/y *is* "distance from root's top-left",
                // i.e. exactly the new width/height, with no separate delta
                // bookkeeping needed and no drift from the grip itself
                // moving as the note grows. Live while pressed; the debounced
                // writer only actually sees it on release (below), not once
                // per pixel.
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    const p = resizeArea.mapToItem(root, mouse.x, mouse.y);
                    root.width = Math.min(Math.max(p.x, root._minW), root._maxW);
                    root.height = Math.min(Math.max(p.y, root._minH), root._maxH);
                }

                onReleased: StickyNotes.update(note.id, { w: root.width, h: root.height })
            }
        }
    }

    HoverHandler { id: hover }

    // Debounced: typing a sentence would otherwise mean a disk write on
    // every keystroke.
    Timer {
        id: saveDebounce
        interval: 600
        onTriggered: StickyNotes.update(note.id, { text: body.text })
    }
}
