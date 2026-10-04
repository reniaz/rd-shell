import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Config
import qs.Services

// Ctrl+Alt+P's animation preset switcher, built in BarStyleSwitcher.qml's
// own style (which itself follows WallpaperSwitcher.qml) so all three read
// as siblings: same scrim, same coverflow, same enter/leave fade, same
// focused-card treatment. What differs is the model -- AnimPresets.presets
// instead of BarStyles.styles -- and what each card shows: not a miniature
// bar, but a dot travelling along that preset's own curve (see the
// `Preview` component below), the one thing a static screenshot of a
// Hyprland animation preset cannot otherwise show at all.
PanelWindow {
    id: root

    property bool open: true
    property bool _entered: false
    readonly property bool shown: root._entered && root.open

    // Same padding trick as BarStyleSwitcher/WallpaperSwitcher, for the same
    // reason: PathView is a closed loop with no switch to turn that off, and
    // a model this short -- four presets today -- would otherwise be strung
    // around the loop and read as looping rather than as four cards with two
    // ends. The blanks bury the seam far enough off both sides that it is
    // never seen, and nothing here assumes the model is exactly four long.
    readonly property int pad: Math.floor(pathView.pathItemCount / 2)

    readonly property var cards: {
        const out = [];
        for (let i = 0; i < root.pad; i++) out.push(null);
        for (const p of AnimPresets.presets) out.push(p);
        for (let i = 0; i < root.pad; i++) out.push(null);
        return out;
    }

    readonly property var currentEntry: AnimPresets.presets[pathView.currentIndex - root.pad] ?? null

    // The focused-card border and its underline marker, in the same live
    // accent pair every popup's two-stop border gradient uses -- not a
    // per-card prediction: a preset recolours nothing, same reasoning
    // BarStyleSwitcher.qml gives for its own identical pair.
    readonly property color focusBorder: Colors.accentBright
    readonly property color focusBorder2: Colors.accent

    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive only while actually open, same reasoning as every overlay in
    // this shell: the fade-out must not go on swallowing keystrokes meant
    // for whatever is behind it.
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-animpresets"
    color: "transparent"

    // The window covers the whole screen and outlives its own fade, so a
    // click meant for the desktop must not be eaten on the way out.
    mask: root.open ? null : closedMask
    Region { id: closedMask }

    function step(delta) {
        const n = AnimPresets.presets.length;
        if (n === 0) return;
        pathView.currentIndex = Math.max(root.pad,
            Math.min(root.pad + n - 1, pathView.currentIndex + delta));
    }

    function activate(entry) {
        if (!entry) return;
        // AnimPresets.apply() writes Settings.animPreset, re-asserts it on
        // the live compositor and closes the panel itself -- the same shape
        // BarStyles.apply()/Wallpapers.apply() have, so there is nothing
        // left to do here once it has been called.
        AnimPresets.apply(entry.id);
    }

    Component.onCompleted: {
        // Opens centred on the preset actually applied, the same as
        // BarStyleSwitcher opens on the style actually applied.
        // positionViewAtIndex moves without animating, unlike assigning
        // currentIndex on its own would, so the strip is never seen sliding
        // in from index 0 before the fade-in below has even started.
        const at = AnimPresets.presets.findIndex(p => p.id === AnimPresets.current);
        pathView.currentIndex = root.pad + (at >= 0 ? at : 0);
        pathView.positionViewAtIndex(pathView.currentIndex, PathView.Center);
        root._entered = true;
    }

    // The miniature drawn on every card: a dot travelling along the curve
    // that preset's `windows`/`workspaces` leaves actually ease on (see
    // hypr/animation-presets.lua) -- a cheap, live stand-in for "what does
    // this animation feel like" that a frozen screenshot of a window move
    // could never show. `curve` below is each preset's own bezier control
    // points, lifted straight out of that Lua file and reshaped into QML's
    // `easing.bezierCurve` array (two control points plus the fixed (1,1)
    // end anchor -- the exact shape Config/Motion.qml's own `spatialCurve`
    // already uses, so this is the established idiom here, not a new one).
    // `minimal` has no such curve to show -- every leaf that moves anything
    // is disabled there -- so its dot fades in place instead of travelling,
    // which is a more honest preview of "fades only" than animating a
    // bezier nothing in that preset actually uses.
    component Preview: Item {
        id: prev

        property string presetId: ""

        readonly property bool isMinimal: prev.presetId === "minimal"

        // Bezier control points for the leaf each non-minimal preset moves
        // windows/workspaces on, straight out of hypr/animation-presets.lua
        // (smooth/snappy share easeOutQuint's shape; only the speed differs,
        // which `travelMs` below stands in for since QML has no "speed"
        // concept separate from a duration). Deliberately not read FROM that
        // Lua file -- QML cannot require() it, and hand-copying four numbers
        // per preset is cheaper than building a bridge for them.
        readonly property var curve: {
            switch (prev.presetId) {
            case "bouncy": return [0.34, 1.56, 0.64, 1, 1, 1]; // "overshoot"
            default:       return [0.23, 1,    0.32, 1, 1, 1]; // "easeOutQuint" (smooth & snappy)
            }
        }
        // Smooth's own `windows` speed is 2.5, snappy's is 4.2, bouncy's is
        // 3 -- roughly inverted into a travel duration so the preview reads
        // faster where the preset actually is faster, without trying to be
        // a literal unit conversion of Hyprland's own "speed".
        readonly property int travelMs: prev.presetId === "snappy" ? 420
            : prev.presetId === "bouncy" ? 640 : 700

        readonly property real trackW: prev.width * 0.56
        readonly property real dotD: Math.max(6, prev.height * 0.11)
        readonly property real trackY: prev.height * 0.58
        readonly property real restX: (prev.width - prev.trackW) / 2
        readonly property real endX: restX + prev.trackW - dot.width

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: prev.trackY
            width: prev.trackW
            height: Math.max(1, Caelus.borderWidth)
            color: Colors.popupBorder
        }

        Rectangle {
            id: dot

            y: prev.trackY - prev.dotD / 2
            width: prev.dotD
            height: prev.dotD
            radius: width / 2
            color: Colors.accentBright
            x: prev.restX
            opacity: prev.isMinimal ? 0.15 : 1

            // Travelling dot: out along the preset's own curve, a short
            // hold, a plain ease back to rest, repeat. Only the non-minimal
            // presets run this -- SequentialAnimation itself gates on
            // `running`, so swapping `presetId` on a card that scrolled out
            // of focus and back just restarts the loop rather than leaving
            // a half-finished one.
            SequentialAnimation {
                running: !prev.isMinimal
                loops: Animation.Infinite

                NumberAnimation {
                    target: dot; property: "x"
                    to: prev.endX
                    duration: prev.travelMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: prev.curve
                }
                PauseAnimation { duration: 320 }
                NumberAnimation {
                    target: dot; property: "x"
                    to: prev.restX
                    duration: Motion.base
                    easing.type: Motion.standard
                }
                PauseAnimation { duration: 320 }
            }

            // Minimal's own preview: no travel, just the fade its own
            // surviving leaves actually keep -- a breathing opacity rather
            // than a moving dot, since nothing in that preset moves one.
            SequentialAnimation {
                running: prev.isMinimal
                loops: Animation.Infinite

                NumberAnimation { target: dot; property: "opacity"; to: 1;    duration: 480; easing.type: Motion.pulse }
                PauseAnimation { duration: 260 }
                NumberAnimation { target: dot; property: "opacity"; to: 0.15; duration: 480; easing.type: Motion.pulse }
                PauseAnimation { duration: 260 }
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
                AnimPresets.panelOpen = false;
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
            onClicked: AnimPresets.panelOpen = false
        }

        Item {
            id: strip

            anchors.fill: parent

            PathView {
                id: pathView

                readonly property real cardWidth: 300
                // A "screen", not a photo -- kept at this window's own
                // aspect ratio, same as BarStyleSwitcher's own path.
                readonly property real cardHeight: root.width > 0
                    ? Math.round(pathView.cardWidth * root.height / root.width)
                    : Math.round(pathView.cardWidth * 9 / 16)
                // WallpaperSwitcher's path below was tuned for a 180-wide
                // card; every x-offset in it is multiplied by this instead
                // of hand-retuning a second set of seventeen numbers for a
                // wider one -- same reasoning BarStyleSwitcher.qml gives.
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
                // BarStyleSwitcher's/WallpaperSwitcher's own does; this is
                // what pulls it back once the pointer lets go.
                onMovementEnded: root.step(0)

                // The same shallow arc as BarStyleSwitcher's/WallpaperSwitcher's
                // own coverflow -- see WallpaperSwitcher.qml's comment on this
                // block for what each PathAttribute drives. Only the
                // x-offsets differ, scaled by `xScale` above for this card's
                // own width.
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
                    // Whether this is the preset actually applied, as
                    // opposed to merely the one centred in the fan -- the
                    // two agree right after opening, and diverge the moment
                    // the strip is stepped.
                    readonly property bool applied: cardRoot.entry?.id === AnimPresets.current

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

                        Preview {
                            anchors.fill: parent
                            presetId: cardRoot.entry?.id ?? ""
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
                    // above: a border on a clipped Rectangle sits behind
                    // whatever that Rectangle draws in paint order and is
                    // covered at its own edge.
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
                    // is underlined -- see BarStyleSwitcher.qml's own for the
                    // same treatment.
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
                        // BarStyleSwitcher: folded cards overlap heavily, so
                        // the one under the pointer is not reliably the one
                        // being aimed at. Once centred, a click applies it,
                        // the same thing Enter does.
                        onClicked: {
                            if (cardRoot.isCurrent) root.activate(cardRoot.entry);
                            else pathView.currentIndex = cardRoot.index;
                        }
                    }
                }
            }

            // Sits above the path and matches it exactly, turning the wheel
            // into single-card steps without touching press or drag --
            // BarStyleSwitcher.qml/WallpaperSwitcher.qml carry the same
            // handler for the same reason.
            Item {
                anchors.fill: pathView

                WheelHandler {
                    onWheel: event => root.step(event.angleDelta.y > 0 ? -1 : 1)
                }
            }

            Text {
                anchors.centerIn: pathView
                visible: AnimPresets.presets.length === 0
                text: "no animation presets"
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
                    text: "animation preset"
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
                    // centred right now is what Hyprland is actually
                    // running.
                    Text {
                        visible: root.currentEntry?.id === AnimPresets.current
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
