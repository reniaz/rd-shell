import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Config
import qs.Services

// Ctrl+Alt+B's bar-style switcher, built in WallpaperSwitcher.qml's own
// style so the two overlays read as siblings: same scrim, same coverflow,
// same enter/leave fade, same focused-card treatment. What differs is the
// model -- BarStyles.styles instead of a browsable folder tree -- and what
// each card shows: not a photo, but a miniature screen, the current
// wallpaper with that style's bar drawn across its top edge in the real
// theme colours. See the `Preview` component below for the drawing itself;
// per BarStyles.qml's header comment, that is "BarStyleSwitcher.qml's
// preview" a new style's miniature belongs in.
PanelWindow {
    id: root

    property bool open: true
    property bool _entered: false
    readonly property bool shown: root._entered && root.open

    // Same padding trick as WallpaperSwitcher, for the same reason: PathView
    // is a closed loop with no switch to turn that off, and a model this
    // short -- two styles today -- would otherwise be strung around the
    // loop and read as looping rather than as two cards with two ends. The
    // blanks bury the seam far enough off both sides that it is never seen,
    // and nothing here assumes the model is exactly two long.
    readonly property int pad: Math.floor(pathView.pathItemCount / 2)

    readonly property var cards: {
        const out = [];
        for (let i = 0; i < root.pad; i++) out.push(null);
        for (const s of BarStyles.styles) out.push(s);
        for (let i = 0; i < root.pad; i++) out.push(null);
        return out;
    }

    readonly property var currentEntry: BarStyles.styles[pathView.currentIndex - root.pad] ?? null

    // The focused-card border and its underline marker, in the same live
    // accent pair every popup's two-stop border gradient uses -- not a
    // per-card prediction the way WallpaperSwitcher's own border is. That one
    // previews what a *wallpaper* would recolour the shell to; a bar style
    // recolours nothing, so there is nothing to predict here.
    readonly property color focusBorder: Colors.accentBright
    readonly property color focusBorder2: Colors.accent

    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive only while actually open, same reasoning as every overlay in
    // this shell: the fade-out must not go on swallowing keystrokes meant
    // for whatever is behind it.
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-barstyles"
    color: "transparent"

    // The window covers the whole screen and outlives its own fade, so a
    // click meant for the desktop must not be eaten on the way out.
    mask: root.open ? null : closedMask
    Region { id: closedMask }

    function step(delta) {
        const n = BarStyles.styles.length;
        if (n === 0) return;
        pathView.currentIndex = Math.max(root.pad,
            Math.min(root.pad + n - 1, pathView.currentIndex + delta));
    }

    function activate(entry) {
        if (!entry) return;
        // BarStyles.apply() writes Settings.barStyle and closes the panel
        // itself -- the same shape Wallpapers.apply() has, so there is
        // nothing left to do here once it has been called.
        BarStyles.apply(entry.id);
    }

    Component.onCompleted: {
        // Opens centred on the style actually applied, the same as
        // WallpaperSwitcher opens on the wallpaper on screen.
        // positionViewAtIndex moves without animating, unlike assigning
        // currentIndex on its own would, so the strip is never seen sliding
        // in from index 0 before the fade-in below has even started.
        const at = BarStyles.styles.findIndex(s => s.id === BarStyles.current);
        pathView.currentIndex = root.pad + (at >= 0 ? at : 0);
        pathView.positionViewAtIndex(pathView.currentIndex, PathView.Center);
        root._entered = true;
    }

    // The miniature drawn on every card: the current wallpaper with that
    // style's bar over its top edge, in the real theme colours. Switches on
    // `styleId`; a new style needs a branch here and nowhere else in this
    // file.
    component Preview: Item {
        id: prev

        property string styleId: ""
        property real screenW: 1920

        readonly property bool isFull: prev.styleId === "full"

        // Every bar-geometry token below is the live one from Caelus.qml
        // times this one ratio, so the miniature keeps the real bar's
        // proportions on whatever monitor this window is on. Not true scale,
        // though: a 44px bar on a card a seventh of the screen wide comes
        // out five pixels tall, too thin to tell islands from a strip at a
        // glance -- and telling them apart is the whole point of the card.
        // `zoom` blows the bar up past the wallpaper's own scale for that.
        readonly property real zoom: 3
        readonly property real scale: prev.screenW > 0 ? prev.width / prev.screenW * prev.zoom : 0
        readonly property real barH: Caelus.barHeight * prev.scale
        readonly property real inset: Caelus.barInset * prev.scale
        readonly property real margin: Caelus.barMargin * prev.scale
        readonly property real islandH: Math.max(3, prev.barH - 2 * prev.inset)
        readonly property real islandR: Math.max(1.5, Caelus.radiusIsland * prev.scale)

        // Three fixed slots -- left group, centre clock, right group --
        // sized as fractions of the card rather than measured off the live
        // bar: this is a miniature, not a mirror, and the real groups
        // resize with however many pills happen to be enabled on whichever
        // machine this shell is running on.
        readonly property real leftW: prev.width * 0.24
        readonly property real centerW: prev.width * 0.18
        readonly property real rightW: prev.width * 0.30
        readonly property real dotY: prev.barH / 2

        // islands: three floating plates, inset from the top and from
        // whichever screen edge they sit nearest.
        Rectangle {
            visible: !prev.isFull
            x: prev.margin
            y: prev.inset
            width: prev.leftW
            height: prev.islandH
            radius: prev.islandR
            color: Colors.barIsland
            border.width: Caelus.borderWidth
            border.color: Colors.barIslandBorder
        }

        Rectangle {
            visible: !prev.isFull
            x: (prev.width - prev.centerW) / 2
            y: prev.inset
            width: prev.centerW
            height: prev.islandH
            radius: prev.islandR
            color: Colors.barIsland
            border.width: Caelus.borderWidth
            border.color: Colors.barIslandBorder
        }

        Rectangle {
            visible: !prev.isFull
            x: prev.width - prev.margin - prev.rightW
            y: prev.inset
            width: prev.rightW
            height: prev.islandH
            radius: prev.islandR
            color: Colors.barIsland
            border.width: Caelus.borderWidth
            border.color: Colors.barIslandBorder
        }

        // full: one strip, flush to the top, left and right edges. Square
        // corners -- the only boundary line this style has is the bottom
        // edge, per BarStyles.qml's style semantics.
        Rectangle {
            visible: prev.isFull
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: prev.barH
            color: Colors.barIsland

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.max(1, Caelus.borderWidth)
                color: Colors.barIslandBorder
            }
        }

        // The pills. Drawn once at the same three x-positions regardless of
        // `isFull`, rather than nested inside the island plates above --
        // `full` has no plate to nest them into, and drawing them at one
        // shared position either way is what makes "pills stay where they
        // are" (BarStyles.qml's style semantics) actually true here instead
        // of merely claimed.
        Row {
            x: prev.margin + (prev.leftW - width) / 2
            y: prev.dotY - height / 2
            spacing: Math.max(1, prev.islandH * 0.2)

            Repeater {
                model: 3

                Rectangle {
                    width: Math.max(2, prev.islandH * 0.4)
                    height: width
                    radius: Caelus.radiusPill
                    color: Colors.fgMuted
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: prev.dotY - height / 2
            width: prev.centerW * 0.55
            height: Math.max(2, prev.islandH * 0.34)
            radius: Caelus.radiusPill
            color: Colors.fgMuted
        }

        Row {
            x: prev.width - prev.margin - prev.rightW + (prev.rightW - width) / 2
            y: prev.dotY - height / 2
            spacing: Math.max(1, prev.islandH * 0.2)

            Repeater {
                model: 4

                Rectangle {
                    width: Math.max(2, prev.islandH * 0.4)
                    height: width
                    radius: Caelus.radiusPill
                    color: Colors.fgMuted
                }
            }
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
                BarStyles.panelOpen = false;
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
            case Qt.Key_Space:
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
            onClicked: BarStyles.panelOpen = false
        }

        Item {
            id: strip

            anchors.fill: parent

            PathView {
                id: pathView

                readonly property real cardWidth: 300
                // A "screen", not a photo -- kept at this window's own
                // aspect ratio rather than a fixed portrait shape, so the
                // miniature's own proportions already look like the monitor
                // it is standing in for.
                readonly property real cardHeight: root.width > 0
                    ? Math.round(pathView.cardWidth * root.height / root.width)
                    : Math.round(pathView.cardWidth * 9 / 16)
                // WallpaperSwitcher's path below was tuned for a 180-wide
                // card; every x-offset in it is multiplied by this instead
                // of hand-retuning a second set of seventeen numbers for a
                // wider one.
                readonly property real xScale: pathView.cardWidth / 180

                width: root.width
                height: pathView.cardHeight + 70
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.height / 2 - pathView.height / 2 - 26

                model: root.cards

                pathItemCount: 15
                snapMode: PathView.SnapOneItem
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: Motion.base
                cacheItemCount: 8
                dragMargin: width / 2

                // A drag overruns past the last real card the same way
                // WallpaperSwitcher's does; this is what pulls it back once
                // the pointer lets go.
                onMovementEnded: root.step(0)

                // The same shallow arc as WallpaperSwitcher's own coverflow
                // -- see that file's comment on this block for what each
                // PathAttribute drives. Only the x-offsets differ, scaled by
                // `xScale` above for this card's own width.
                path: Path {
                    startX: pathView.width / 2 - 952.4 * pathView.xScale
                    startY: pathView.height / 2
                    PathAttribute { name: "itemAngle"; value: 38 }
                    PathAttribute { name: "itemScale"; value: 0.62 }
                    PathAttribute { name: "itemZ"; value: 0 }
                    PathAttribute { name: "itemOpacity"; value: 0 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 - 866.6 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.03333 }
                    PathAttribute { name: "itemAngle"; value: 36 }
                    PathAttribute { name: "itemScale"; value: 0.64 }
                    PathAttribute { name: "itemZ"; value: 2 }
                    PathAttribute { name: "itemOpacity"; value: 0 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 - 777.1 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.10000 }
                    PathAttribute { name: "itemAngle"; value: 34 }
                    PathAttribute { name: "itemScale"; value: 0.68 }
                    PathAttribute { name: "itemZ"; value: 4 }
                    PathAttribute { name: "itemOpacity"; value: 0.42 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 - 679.3 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.16667 }
                    PathAttribute { name: "itemAngle"; value: 31 }
                    PathAttribute { name: "itemScale"; value: 0.72 }
                    PathAttribute { name: "itemZ"; value: 6 }
                    PathAttribute { name: "itemOpacity"; value: 0.62 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 - 572.1 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.23333 }
                    PathAttribute { name: "itemAngle"; value: 27 }
                    PathAttribute { name: "itemScale"; value: 0.76 }
                    PathAttribute { name: "itemZ"; value: 8 }
                    PathAttribute { name: "itemOpacity"; value: 0.68 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 - 453.9 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.30000 }
                    PathAttribute { name: "itemAngle"; value: 22 }
                    PathAttribute { name: "itemScale"; value: 0.81 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemOpacity"; value: 0.72 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 - 323.3 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.36667 }
                    PathAttribute { name: "itemAngle"; value: 16 }
                    PathAttribute { name: "itemScale"; value: 0.86 }
                    PathAttribute { name: "itemZ"; value: 12 }
                    PathAttribute { name: "itemOpacity"; value: 0.76 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 - 179.6 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.43333 }
                    PathAttribute { name: "itemAngle"; value: 9 }
                    PathAttribute { name: "itemScale"; value: 0.92 }
                    PathAttribute { name: "itemZ"; value: 14 }
                    PathAttribute { name: "itemOpacity"; value: 0.82 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 + 0.0; y: pathView.height / 2 }
                    PathPercent { value: 0.50000 }
                    PathAttribute { name: "itemAngle"; value: 0 }
                    PathAttribute { name: "itemScale"; value: 1.26 }
                    PathAttribute { name: "itemZ"; value: 30 }
                    PathAttribute { name: "itemOpacity"; value: 1 }
                    PathAttribute { name: "itemLift"; value: -18 }

                    PathLine { x: pathView.width / 2 + 179.6 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.56667 }
                    PathAttribute { name: "itemAngle"; value: -9 }
                    PathAttribute { name: "itemScale"; value: 0.92 }
                    PathAttribute { name: "itemZ"; value: 14 }
                    PathAttribute { name: "itemOpacity"; value: 0.82 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 + 323.3 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.63333 }
                    PathAttribute { name: "itemAngle"; value: -16 }
                    PathAttribute { name: "itemScale"; value: 0.86 }
                    PathAttribute { name: "itemZ"; value: 12 }
                    PathAttribute { name: "itemOpacity"; value: 0.76 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 + 453.9 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.70000 }
                    PathAttribute { name: "itemAngle"; value: -22 }
                    PathAttribute { name: "itemScale"; value: 0.81 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemOpacity"; value: 0.72 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 + 572.1 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.76667 }
                    PathAttribute { name: "itemAngle"; value: -27 }
                    PathAttribute { name: "itemScale"; value: 0.76 }
                    PathAttribute { name: "itemZ"; value: 8 }
                    PathAttribute { name: "itemOpacity"; value: 0.68 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 + 679.3 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.83333 }
                    PathAttribute { name: "itemAngle"; value: -31 }
                    PathAttribute { name: "itemScale"; value: 0.72 }
                    PathAttribute { name: "itemZ"; value: 6 }
                    PathAttribute { name: "itemOpacity"; value: 0.62 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 + 777.1 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.90000 }
                    PathAttribute { name: "itemAngle"; value: -34 }
                    PathAttribute { name: "itemScale"; value: 0.68 }
                    PathAttribute { name: "itemZ"; value: 4 }
                    PathAttribute { name: "itemOpacity"; value: 0.42 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 + 866.6 * pathView.xScale; y: pathView.height / 2 }
                    PathPercent { value: 0.96667 }
                    PathAttribute { name: "itemAngle"; value: -36 }
                    PathAttribute { name: "itemScale"; value: 0.64 }
                    PathAttribute { name: "itemZ"; value: 2 }
                    PathAttribute { name: "itemOpacity"; value: 0 }
                    PathAttribute { name: "itemLift"; value: 0 }

                    PathLine { x: pathView.width / 2 + 952.4 * pathView.xScale; y: pathView.height / 2 }
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
                    // The blanks padding both ends of the model.
                    readonly property bool filler: !cardRoot.entry
                    readonly property bool isCurrent: cardRoot.PathView.isCurrentItem
                    // Whether this is the style actually applied, as opposed
                    // to merely the one centred in the fan -- the two agree
                    // right after opening, and diverge the moment the strip
                    // is stepped.
                    readonly property bool applied: cardRoot.entry?.id === BarStyles.current

                    visible: !cardRoot.filler

                    width: pathView.cardWidth
                    height: pathView.cardHeight
                    // See WallpaperSwitcher.qml's own delegate for why every
                    // one of these falls back to a resting value: the cache
                    // holds delegates off the path with no attached
                    // attributes at all, and an undefined read here would
                    // otherwise reach the perspective transform below as a
                    // NaN.
                    scale: cardRoot.PathView.itemScale ?? 1
                    opacity: cardRoot.PathView.itemOpacity ?? 0
                    z: cardRoot.PathView.itemZ ?? 0

                    transform: [
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
                        color: Colors.surfaceRaised

                        Image {
                            anchors.fill: parent
                            visible: Wallpapers.current !== ""
                            source: Wallpapers.current !== "" ? "file://" + Wallpapers.current : ""
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 440
                            sourceSize.height: 280
                            retainWhileLoading: true
                        }

                        Preview {
                            anchors.fill: parent
                            styleId: cardRoot.entry?.id ?? ""
                            screenW: root.width
                        }

                        Text {
                            visible: cardRoot.applied
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: Caelus.spaceTight
                            text: "check_circle"
                            font.family: Caelus.symbolFamily
                            font.pixelSize: Caelus.sizeBody
                            color: Colors.accentBright
                        }
                    }

                    // Own Rectangle rather than a border on the clipped one
                    // above: a border on a clipped, image-filled Rectangle
                    // sits behind that image in paint order and is covered
                    // at its own edge.
                    Rectangle {
                        anchors.fill: parent
                        radius: Caelus.radiusCard
                        color: "transparent"
                        border.width: cardRoot.isCurrent ? 2 : Caelus.borderWidth
                        border.color: cardRoot.isCurrent ? root.focusBorder : Colors.surfaceHover

                        Behavior on border.color { ColorAnimation { duration: Motion.base } }
                        Behavior on border.width { NumberAnimation { duration: Motion.base } }
                    }

                    // A marker under the selected card, the way a current tab
                    // is underlined -- see WallpaperSwitcher.qml's own for
                    // the same treatment.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height + 12
                        width: cardRoot.isCurrent ? 36 : 0
                        height: 3
                        radius: Caelus.radiusPill
                        gradient: Gradient {
                            orientation: Gradient.Horizontal

                            GradientStop { position: 0; color: root.focusBorder }
                            GradientStop { position: 1; color: root.focusBorder2 }
                        }
                        opacity: cardRoot.isCurrent ? 1 : 0

                        Behavior on width { NumberAnimation { duration: Motion.slow; easing.type: Motion.standard } }
                        Behavior on opacity { NumberAnimation { duration: Motion.base } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        // A click off to the side brings that card to the
                        // middle instead of acting on it, same as
                        // WallpaperSwitcher: folded cards overlap heavily,
                        // so the one under the pointer is not reliably the
                        // one being aimed at. Once centred, a click applies
                        // it, the same thing Enter does.
                        onClicked: {
                            if (cardRoot.isCurrent) root.activate(cardRoot.entry);
                            else pathView.currentIndex = cardRoot.index;
                        }
                    }
                }
            }

            // Sits above the path and matches it exactly, turning the wheel
            // into single-card steps without touching press or drag --
            // WallpaperSwitcher.qml carries the same handler for the same
            // reason.
            Item {
                anchors.fill: pathView

                WheelHandler {
                    onWheel: event => root.step(event.angleDelta.y > 0 ? -1 : 1)
                }
            }

            Text {
                anchors.centerIn: pathView
                visible: BarStyles.styles.length === 0
                text: "no bar styles"
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
                    text: "bar style"
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Caelus.spaceTight

                    // The same "applied" mark the card corner carries,
                    // repeated here so the caption alone -- without a card
                    // in view at all -- can still say whether what is
                    // centred right now is what the bar is actually
                    // wearing.
                    Text {
                        visible: root.currentEntry?.id === BarStyles.current
                        anchors.verticalCenter: parent.verticalCenter
                        text: "check_circle"
                        font.family: Caelus.symbolFamily
                        font.pixelSize: Caelus.sizeBody
                        color: Colors.accentBright
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.currentEntry?.name ?? ""
                        color: Colors.fgDim
                        font.family: Caelus.fontFamily
                        font.pixelSize: Caelus.sizeBody
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 280
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.currentEntry?.description ?? ""
                    color: Colors.fgMuted
                    font.family: Caelus.fontFamily
                    font.pixelSize: Caelus.sizeLabel
                }
            }
        }
    }
}
