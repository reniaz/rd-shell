import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Config
import qs.Services

// A fullscreen coverflow over ~/Pictures/wall, bound to Ctrl+Alt+F by the
// lead's Hyprland binding and toggled through Wallpapers.panelOpen.
//
// It dims what is behind it. The first cut deliberately did not, on the
// grounds that you are choosing a wallpaper and should see the one you have --
// but what is actually behind this overlay is whatever you were working in,
// and the cards nearest the ends of the path sit at 0.35 opacity by design.
// Unscrimmed, those cards read as smears over somebody else's text. The scrim
// is the same one every modal in the caelus palette uses.
PanelWindow {
    id: root

    // Written by the PopupLoader the lead wires this into, the same shape
    // every overlay in this shell uses (see PowerMenu.qml): default true
    // because the window exists before its loader can reach it, driven false
    // to play the fade below before the window is actually torn down.
    property bool open: true

    // Raised once the window exists, so the first frame drawn is the faded-out
    // one and the strip is seen to arrive rather than appearing already there.
    property bool _entered: false
    readonly property bool shown: root._entered && root.open

    // The entry the path is currently centred on, read by Enter and by the
    // caption underneath the strip. Bounds-checked because the model can
    // legitimately be empty for a moment -- a folder with nothing in it, or a
    // scan still running -- and PathView answers -1 for currentIndex then.
    readonly property var currentEntry: Wallpapers.entries[pathView.currentIndex - root.pad] ?? null

    // Drives the accent swatches under the strip. Only an image has colours to
    // predict; a folder or the back card clears them rather than leaving the
    // previous wallpaper's swatches sitting under a card they do not describe.
    // Cleared on the way out so a closed panel is not holding a preview.
    readonly property string previewPath: root.currentEntry?.kind === "image"
        ? (root.currentEntry?.path ?? "") : ""

    // The two stops Hyprland's active window border is actually built from --
    // wallpaper-apply.sh feeds `primary` and `secondary` straight into
    // `col.active_border` as a 45-degree gradient. Showing the card's own edge
    // and its marker in these is the point: the border you are looking at in
    // the strip is the border you will be looking at on every window after you
    // press Enter. Falls back to the live accent until matugen has answered,
    // so nothing ever renders borderless while a preview is in flight.
    readonly property color previewBorder: Wallpapers.previewRoles?.primary ?? Colors.accentBright
    readonly property color previewBorder2: Wallpapers.previewRoles?.secondary ?? Colors.accent

    onPreviewPathChanged: Wallpapers.previewPath = root.previewPath
    Component.onDestruction: Wallpapers.previewPath = ""

    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive only while actually open, exactly like PowerMenu: the strip
    // reads Enter and hjkl, but holding the whole keyboard through the fade-out
    // would swallow a keystroke meant for whatever is behind it.
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-wallpapers"
    color: "transparent"

    // Same reasoning as every other overlay here: the window covers the whole
    // screen and outlives its own fade, so a click meant for the desktop must
    // not be eaten by a strip that is already on its way out.
    mask: root.open ? null : closedMask
    Region { id: closedMask }

    Component.onCompleted: {
        root._entered = true;
        // The first centred card exists before this window does, so its
        // preview has to be asked for here rather than waiting for the path
        // to change to something it already is.
        Wallpapers.previewPath = root.previewPath;
    }

    // PathView is a closed loop: item 0 sits next to the last item and the
    // strip will happily spin round forever. This list has two ends -- the
    // folders at the left, the last wallpaper at the right -- so every way of
    // moving it goes through here and stops at them, and the delegate hides
    // the copies PathView still draws past the seam.
    function step(delta) {
        const n = Wallpapers.entries.length;
        if (n === 0) return;
        pathView.currentIndex = Math.max(root.pad,
            Math.min(root.pad + n - 1, pathView.currentIndex + delta));
    }

    // Half a strip of blanks at each end of the model.
    //
    // PathView is a closed loop and there is no switching that off: item 0 is
    // always drawn next to the last item, and it only spaces items one
    // `pathItemCount` apart once the model is at least that long -- a folder
    // of six wallpapers would otherwise be strung out across the whole screen
    // while a folder of nine hundred came out packed. Padding both ends
    // settles both at once. The model is never shorter than a strip, so the
    // spacing is always the same; and the seam where the loop closes is
    // buried in blanks, seven cards past the last real one, so the folders
    // really are the left end and the last wallpaper really is the right.
    readonly property int pad: Math.floor(pathView.pathItemCount / 2)

    readonly property var cards: {
        const out = [];
        for (let i = 0; i < root.pad; i++) out.push(null);
        for (const e of Wallpapers.entries) out.push(e);
        for (let i = 0; i < root.pad; i++) out.push(null);
        return out;
    }

    function activate(entry) {
        if (!entry) return;
        switch (entry.kind) {
        case "image":
            Wallpapers.apply(entry.path);
            break;
        case "folder":
            Wallpapers.open(entry.path);
            break;
        case "back":
            Wallpapers.back();
            break;
        }
    }

    Item {
        id: input

        anchors.fill: parent
        focus: true
        opacity: root.shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                Wallpapers.panelOpen = false;
                break;
            case Qt.Key_Left:
            case Qt.Key_H:
                root.step(-1);
                break;
            case Qt.Key_Right:
            case Qt.Key_L:
                root.step(1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.activate(root.currentEntry);
                break;
            default:
                return;
            }
            event.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.scrim
        }

        // Drawn first, under the strip, so it only ever catches a click the
        // strip and the caption did not want -- the same click-outside-
        // dismisses convention every popup in this shell already uses.
        MouseArea {
            anchors.fill: parent
            onClicked: Wallpapers.panelOpen = false
        }

        Item {
            id: strip

            anchors.fill: parent

            // Entering or leaving a folder swaps the whole model out from under
            // the view, and the cards for the new folder do not arrive with the
            // decision to go there: the scan is a subprocess, and a folder like
            // Wallhaven takes seconds the first time while its thumbnails are
            // built. So the two halves are driven by the two separate events
            // rather than run back to back -- out when the directory changes,
            // back in when its listing actually lands. Run as one sequence, the
            // fade was over long before the cards existed and they appeared at
            // full opacity with no transition at all, which is the snap this is
            // here to hide.
            //
            // Only the cards fade. The caption and the "scanning…" line sit
            // outside this and stay up, so a slow folder says so instead of
            // leaving the screen blank.
            NumberAnimation {
                id: leave
                target: pathView; property: "opacity"; to: 0
                duration: Motion.fast; easing.type: Motion.exit
            }

            NumberAnimation {
                id: arrive
                target: pathView; property: "opacity"; to: 1
                duration: Motion.slow; easing.type: Motion.standard
            }

            Connections {
                target: Wallpapers

                function onDirChanged() {
                    arrive.stop();
                    leave.restart();
                }

                // Where the strip lands when a folder's listing arrives. Not
                // left to PathView: it is handed an empty model first (see
                // Wallpapers._scan) and settles wherever the refill happens to
                // put it, which is why the panel used to open one card past
                // the front. Centred on the wallpaper actually in use when
                // this folder is the one it came from -- walking back into it
                // then opens on what you are looking at rather than on the
                // alphabetical first thing in the directory.
                function onEntriesChanged() {
                    // An empty folder leaves currentIndex pointing wherever
                    // the last, longer folder had it. Nothing reads it while
                    // there are no entries, but the next listing to arrive
                    // would be positioned from a stale number, so it goes back
                    // to the middle of the padding.
                    if (Wallpapers.entries.length === 0) {
                        pathView.currentIndex = root.pad;
                        return;
                    }

                    // The wallpaper in use, if it lives here. Otherwise the
                    // first image -- not index 0, which is the back card or a
                    // folder. The scan puts folders first precisely so they
                    // sit off to the left where they are out of the way, and
                    // opening centred on one would undo that: you would arrive
                    // looking at a directory rather than at wallpapers.
                    let at = Wallpapers.entries.findIndex(e => e.path === Wallpapers.current);
                    if (at < 0) at = Wallpapers.entries.findIndex(e => e.kind === "image");
                    pathView.currentIndex = root.pad + (at >= 0 ? at : 0);
                    pathView.positionViewAtIndex(pathView.currentIndex, PathView.Center);
                    leave.stop();
                    arrive.restart();
                }
            }

            PathView {
                id: pathView

                readonly property real cardWidth: 180
                readonly property real cardHeight: 400

                width: root.width
                height: pathView.cardHeight + 90
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.height / 2 - pathView.height / 2 - 26

                model: root.cards

                // Cards sit closer together than they are wide, so the fan
                // overlaps: each one covers roughly the outer third of the
                // card behind it, the way a hand of cards spread on a table
                // does. Raising this packs them tighter, lowering it opens
                // gaps between them.
                pathItemCount: 15
                snapMode: PathView.SnapOneItem
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                // Short enough that a wheel spun quickly keeps up with the
                // hand rather than queueing a string of 260ms steps and
                // arriving somewhere the user stopped asking for.
                highlightMoveDuration: Motion.base
                // A few delegates either side of what the path shows, so a
                // fast scroll finds its next card already built instead of
                // creating one and decoding a thumbnail mid-step.
                cacheItemCount: 8
                // Wide enough that a drag started anywhere on the strip, not
                // just on a card, still scrolls it -- cards shrink toward the
                // ends of the path and the gaps between them are real dead
                // space otherwise.
                dragMargin: width / 2

                // A drag is the one gesture that does not go through step():
                // PathView moves its own offset while the pointer is down, and
                // taking that over would cost the swipe its feel. So it is
                // allowed to overrun, and is pulled back to the last real card
                // once the pointer lets go. Everything past the end is blank
                // while it overruns, so the strip reads as having run out
                // rather than as having looped.
                onMovementEnded: root.step(0)

                // A shallow arc: the centre sits a little higher than the two
                // ends, curving through PathQuad rather than a straight line,
                // and the PathAttributes at 0%, 50% and 100% are what actually
                // drive each card's scale, opacity and stacking as it passes
                // along it. This is the shape Qt's own PathView examples use
                // for a coverflow, and it is what pathItemCount / snapMode /
                // the highlight range above are built to animate between.
                // A straight line across the screen, not an arc. The angle
                // attribute is what makes it read as depth: cards left of the
                // middle are turned to face right and cards right of it to
                // face left, so the strip reads as a hand of cards fanned out
                // around the one you are looking at.
                //
                // There is one waypoint per card position, because a card only
                // ever comes to rest on one of them -- `pathItemCount` slots
                // spread evenly over the path -- and writing the values there
                // is what lets each card's angle, size and spacing be chosen
                // rather than fallen into. Between them the attributes
                // interpolate, which is the motion you see while it scrolls.
                //
                // The x positions are deliberately not evenly spaced. A card
                // turned 34 degrees at two thirds size lands barely half as
                // wide as the upright one in the middle, so even spacing put
                // the near cards on top of each other and left gaps between
                // the far ones. Each step is sized from how wide the two cards
                // it separates actually render, which is what makes the gaps
                // look the same all the way out.
                //
                // Both ends are at zero opacity and the last card with any is
                // one slot short of them, so a card entering or leaving the
                // strip does it where there is nothing to see. Without that it
                // blinked into existence at two thirds size.
                path: Path {
                    startX: pathView.width / 2 -952.4
                    startY: pathView.height / 2
                    PathAttribute { name: "itemAngle"; value: 38 }
                    PathAttribute { name: "itemScale"; value: 0.62 }
                    PathAttribute { name: "itemZ"; value: 0 }
                    PathAttribute { name: "itemOpacity"; value: 0 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 -866.6; y: pathView.height / 2 }
                    PathPercent { value: 0.03333 }
                    PathAttribute { name: "itemAngle"; value: 36 }
                    PathAttribute { name: "itemScale"; value: 0.64 }
                    PathAttribute { name: "itemZ"; value: 2 }
                    PathAttribute { name: "itemOpacity"; value: 0 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 -777.1; y: pathView.height / 2 }
                    PathPercent { value: 0.10000 }
                    PathAttribute { name: "itemAngle"; value: 34 }
                    PathAttribute { name: "itemScale"; value: 0.68 }
                    PathAttribute { name: "itemZ"; value: 4 }
                    PathAttribute { name: "itemOpacity"; value: 0.42 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 -679.3; y: pathView.height / 2 }
                    PathPercent { value: 0.16667 }
                    PathAttribute { name: "itemAngle"; value: 31 }
                    PathAttribute { name: "itemScale"; value: 0.72 }
                    PathAttribute { name: "itemZ"; value: 6 }
                    PathAttribute { name: "itemOpacity"; value: 0.62 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 -572.1; y: pathView.height / 2 }
                    PathPercent { value: 0.23333 }
                    PathAttribute { name: "itemAngle"; value: 27 }
                    PathAttribute { name: "itemScale"; value: 0.76 }
                    PathAttribute { name: "itemZ"; value: 8 }
                    PathAttribute { name: "itemOpacity"; value: 0.68 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 -453.9; y: pathView.height / 2 }
                    PathPercent { value: 0.30000 }
                    PathAttribute { name: "itemAngle"; value: 22 }
                    PathAttribute { name: "itemScale"; value: 0.81 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemOpacity"; value: 0.72 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 -323.3; y: pathView.height / 2 }
                    PathPercent { value: 0.36667 }
                    PathAttribute { name: "itemAngle"; value: 16 }
                    PathAttribute { name: "itemScale"; value: 0.86 }
                    PathAttribute { name: "itemZ"; value: 12 }
                    PathAttribute { name: "itemOpacity"; value: 0.76 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 -179.6; y: pathView.height / 2 }
                    PathPercent { value: 0.43333 }
                    PathAttribute { name: "itemAngle"; value: 9 }
                    PathAttribute { name: "itemScale"; value: 0.92 }
                    PathAttribute { name: "itemZ"; value: 14 }
                    PathAttribute { name: "itemOpacity"; value: 0.82 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 +0.0; y: pathView.height / 2 }
                    PathPercent { value: 0.50000 }
                    PathAttribute { name: "itemAngle"; value: 0 }
                    PathAttribute { name: "itemScale"; value: 1.26 }
                    PathAttribute { name: "itemZ"; value: 30 }
                    PathAttribute { name: "itemOpacity"; value: 1 }
                    PathAttribute { name: "itemLift"; value: -18 }

                    PathLine { x: pathView.width / 2 +179.6; y: pathView.height / 2 }
                    PathPercent { value: 0.56667 }
                    PathAttribute { name: "itemAngle"; value: -9 }
                    PathAttribute { name: "itemScale"; value: 0.92 }
                    PathAttribute { name: "itemZ"; value: 14 }
                    PathAttribute { name: "itemOpacity"; value: 0.82 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 +323.3; y: pathView.height / 2 }
                    PathPercent { value: 0.63333 }
                    PathAttribute { name: "itemAngle"; value: -16 }
                    PathAttribute { name: "itemScale"; value: 0.86 }
                    PathAttribute { name: "itemZ"; value: 12 }
                    PathAttribute { name: "itemOpacity"; value: 0.76 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 +453.9; y: pathView.height / 2 }
                    PathPercent { value: 0.70000 }
                    PathAttribute { name: "itemAngle"; value: -22 }
                    PathAttribute { name: "itemScale"; value: 0.81 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemOpacity"; value: 0.72 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 +572.1; y: pathView.height / 2 }
                    PathPercent { value: 0.76667 }
                    PathAttribute { name: "itemAngle"; value: -27 }
                    PathAttribute { name: "itemScale"; value: 0.76 }
                    PathAttribute { name: "itemZ"; value: 8 }
                    PathAttribute { name: "itemOpacity"; value: 0.68 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 +679.3; y: pathView.height / 2 }
                    PathPercent { value: 0.83333 }
                    PathAttribute { name: "itemAngle"; value: -31 }
                    PathAttribute { name: "itemScale"; value: 0.72 }
                    PathAttribute { name: "itemZ"; value: 6 }
                    PathAttribute { name: "itemOpacity"; value: 0.62 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 +777.1; y: pathView.height / 2 }
                    PathPercent { value: 0.90000 }
                    PathAttribute { name: "itemAngle"; value: -34 }
                    PathAttribute { name: "itemScale"; value: 0.68 }
                    PathAttribute { name: "itemZ"; value: 4 }
                    PathAttribute { name: "itemOpacity"; value: 0.42 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 +866.6; y: pathView.height / 2 }
                    PathPercent { value: 0.96667 }
                    PathAttribute { name: "itemAngle"; value: -36 }
                    PathAttribute { name: "itemScale"; value: 0.64 }
                    PathAttribute { name: "itemZ"; value: 2 }
                    PathAttribute { name: "itemOpacity"; value: 0 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 +952.4; y: pathView.height / 2 }
                    PathPercent { value: 1.00000 }
                    PathAttribute { name: "itemAngle"; value: -38 }
                    PathAttribute { name: "itemScale"; value: 0.62 }
                    PathAttribute { name: "itemZ"; value: 0 }
                    PathAttribute { name: "itemOpacity"; value: 0 }
                    PathAttribute { name: "itemLift"; value: 0 }
                }

                delegate: Item {
                    id: cardRoot

                    required property var modelData
                    required property int index

                    readonly property var entry: cardRoot.modelData
                    readonly property bool isImage: cardRoot.entry?.kind === "image"
                    readonly property bool isCurrent: cardRoot.PathView.isCurrentItem

                    // The blanks that pad both ends of the model.
                    readonly property bool filler: !cardRoot.entry
                    visible: !cardRoot.filler

                    width: pathView.cardWidth
                    height: pathView.cardHeight
                    // Every one of these falls back to a resting value.
                    // PathView keeps `cacheItemCount` delegates alive off the
                    // path, and those have no attached attributes at all --
                    // the reads come back undefined. Undefined through the
                    // perspective matrix below is a NaN in the projection,
                    // and a NaN there does not make a card vanish, it makes
                    // the quad degenerate: one was drawn below the strip as a
                    // huge skewed wedge of stretched thumbnail.
                    scale: cardRoot.PathView.itemScale ?? 1
                    opacity: cardRoot.PathView.itemOpacity ?? 0
                    z: cardRoot.PathView.itemZ ?? 0

                    // The fold. Rotating about the vertical axis through the
                    // card's own centre, so a card turns in place as it passes
                    // the middle instead of swinging sideways. The Matrix4x4
                    // after it is a perspective divide on z -- without one the
                    // rotation projects flat and a turned card is just a
                    // narrower rectangle, with no sense of an edge nearer to
                    // you than the other.
                    transform: [
                        // The selected card stands up out of the row. Applied
                        // as a transform rather than to `y` because PathView
                        // owns the delegate's position and would fight a
                        // binding on it.
                        Translate { y: cardRoot.PathView.itemLift ?? 0 },
                        Rotation {
                            origin.x: cardRoot.width / 2
                            origin.y: cardRoot.height / 2
                            axis { x: 0; y: 1; z: 0 }
                            angle: cardRoot.PathView.itemAngle ?? 0
                        },
                        Matrix4x4 {
                            matrix: Qt.matrix4x4(1, 0, 0, 0,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, -0.0011, 1)
                        }
                    ]

                    Rectangle {
                        anchors.fill: parent
                        radius: Caelus.radiusCard
                        clip: true
                        color: cardRoot.isImage ? Colors.surface : Colors.surfaceRaised

                        Image {
                            anchors.fill: parent
                            clip: true
                            // Folder cards carry one too -- the first
                            // wallpaper anywhere underneath -- held well back
                            // so the glyph and the name stay the thing you
                            // read. It is what tells you at a glance that
                            // there is something in there, which a flat card
                            // with a folder glyph on it never did.
                            visible: !!cardRoot.entry?.thumb
                            opacity: cardRoot.isImage ? 1 : 0.4
                            source: cardRoot.entry?.thumb ?? ""
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            // Pinned to the thumbnail's own on-disk size, not
                            // to this Image's animated width/height: sourceSize
                            // is part of the decode cache key, and a size that
                            // rode the card's `scale` transform would force a
                            // full JPEG re-decode on every frame of the path
                            // animation instead of once.
                            sourceSize.width: 440
                            sourceSize.height: 680
                            // Keeps the previous frame on screen while a new
                            // source decodes, instead of a blank flash -- most
                            // visible re-entering a folder, where every visible
                            // thumbnail's source changes at once.
                            retainWhileLoading: true
                        }

                        // Holds the cover back far enough to read text over,
                        // and gives a folder with nothing under it the same
                        // weight as one that has a cover.
                        Rectangle {
                            anchors.fill: parent
                            visible: !cardRoot.isImage && !cardRoot.filler
                            color: Colors.surface
                            opacity: 0.55
                        }

                        // Folder cards read as a different kind of thing from a
                        // photo at a glance: a glyph on a flat card instead of
                        // an image filling it, in the bright accent so it
                        // never gets mistaken for body text.
                        Column {
                            visible: !cardRoot.isImage
                            anchors.centerIn: parent
                            width: parent.width - 24
                            spacing: Caelus.spaceLoose

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cardRoot.entry?.kind === "back" ? "arrow_back" : "folder"
                                color: Colors.accentBright
                                font.family: Caelus.symbolFamily
                                font.pixelSize: 56
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                text: cardRoot.entry?.name ?? ""
                                color: Colors.fg
                                font.family: Caelus.fontFamily
                                font.pixelSize: Caelus.sizeBody
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: cardRoot.entry?.kind === "folder"
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (cardRoot.entry?.count ?? 0) + " wallpapers"
                                color: Colors.fgMuted
                                font.family: Caelus.fontFamily
                                font.pixelSize: Caelus.sizeLabel
                            }
                        }
                    }

                    // The selection outline, on its own Rectangle rather than
                    // on the clipped one above: a border drawn as part of a
                    // clipped, image-filled Rectangle sits behind that image
                    // in paint order and would be covered at its own edge.
                    Rectangle {
                        anchors.fill: parent
                        radius: Caelus.radiusCard
                        color: "transparent"
                        // Two pixels on the selected card against one hairline
                        // everywhere else. The unselected border is not
                        // transparent: every card carries a faint edge, so the
                        // fan has definition where thumbnails run dark, and
                        // the selection reads as that same edge brightening
                        // rather than as a frame appearing out of nothing.
                        border.width: cardRoot.isCurrent ? 2 : Caelus.borderWidth
                        // The centred card wears the border this wallpaper
                        // would give every window, not the one the shell is
                        // wearing now.
                        border.color: cardRoot.isCurrent ? root.previewBorder : Colors.surfaceHover

                        Behavior on border.color { ColorAnimation { duration: Motion.base } }
                        Behavior on border.width { NumberAnimation { duration: Motion.base } }
                    }

                    // A marker under the selected card, the way a current tab
                    // is underlined. The scale and the lift already say which
                    // card it is; this says it again in a way that survives a
                    // dark thumbnail, and it is the one piece of the strip
                    // drawn in the accent, so the eye has somewhere to land.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height + 12
                        width: cardRoot.isCurrent ? 36 : 0
                        height: 3
                        radius: Caelus.radiusPill
                        // Both stops, left to right, because the real border is
                        // a two-colour gradient and a marker drawn in only the
                        // first one would under-promise what lands on screen.
                        gradient: Gradient {
                            orientation: Gradient.Horizontal

                            GradientStop { position: 0; color: root.previewBorder }
                            GradientStop { position: 1; color: root.previewBorder2 }
                        }
                        opacity: cardRoot.isCurrent ? 1 : 0

                        Behavior on width { NumberAnimation { duration: Motion.slow; easing.type: Motion.standard } }
                        Behavior on opacity { NumberAnimation { duration: Motion.base } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        // A genuine drag never reaches onClicked. PathView is
                        // not a Flickable -- it derives straight from Item and
                        // does its own dragging -- but dragging the path is
                        // documented to work by pressing on a delegate, so it
                        // takes the grab off this MouseArea itself once the
                        // pointer passes the drag threshold. Nothing bespoke is
                        // needed here to tell a click from a drag.
                        //
                        // A click off to the side brings that card to the
                        // middle instead of acting on it. Folded cards overlap
                        // heavily by design, so the one the pointer is over is
                        // not reliably the one being aimed at -- and acting on
                        // the wrong card is exactly the complaint this strip
                        // had. Once a card is the centred one, a click applies
                        // it, which is the same thing Enter does.
                        onClicked: {
                            if (cardRoot.isCurrent) root.activate(cardRoot.entry);
                            else pathView.currentIndex = cardRoot.index;
                        }
                    }
                }
            }

            // Sits above the path and matches it exactly, so it can turn the
            // wheel into single-card steps without touching press or drag at
            // all: a WheelHandler only ever answers wheel events, so drag-to-
            // scroll keeps going straight through it to PathView underneath.
            // Without it the wheel would do nothing over the strip -- PathView
            // derives from Item, not from Flickable, and Item has no wheel
            // behaviour of its own to inherit.
            Item {
                anchors.fill: pathView

                WheelHandler {
                    onWheel: event => root.step(event.angleDelta.y > 0 ? -1 : 1)
                }
            }

            Text {
                anchors.centerIn: pathView
                visible: Wallpapers.entries.length === 0
                text: Wallpapers.scanning ? "scanning…" : "nothing here"
                color: Colors.fgMuted
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
            }

            Column {
                anchors.top: pathView.bottom
                anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Caelus.spaceTight

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Wallpapers.label !== "" ? Wallpapers.label : "wall"
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.currentEntry?.name ?? ""
                    color: Colors.fgDim
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeBody
                }

                // What this wallpaper would recolour the shell to, computed by
                // matugen before it is applied -- the four roles the bar
                // actually paints with, in the order they carry weight. The
                // row keeps its height whether or not there is an answer yet,
                // so the name above it does not jump when one arrives.
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: swatches.width
                    height: 14
                    opacity: Wallpapers.previewRoles !== null ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: Motion.base } }

                    Row {
                        id: swatches

                        anchors.centerIn: parent
                        spacing: Caelus.spaceTight

                        Repeater {
                            model: ["primary", "secondary", "tertiary", "error"]

                            Rectangle {
                                required property string modelData

                                width: 22
                                height: 10
                                radius: Caelus.radiusPill
                                color: Wallpapers.previewRoles?.[modelData] ?? "transparent"
                                border.width: Caelus.borderWidth
                                border.color: Colors.surfaceHover

                                Behavior on color { ColorAnimation { duration: Motion.base } }
                            }
                        }
                    }
                }
            }
        }
    }
}
