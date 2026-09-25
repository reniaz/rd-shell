import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// A hover-revealed strip on the outer edge of one monitor, the way
// caelestia-shell does it -- caelestia's own edge panel is a thin trigger
// zone that grows a card when the pointer arrives and folds it away again
// when the pointer leaves. This shell's version carries per-monitor DDC
// brightness and contrast (Services/Ddc.qml -- these are desktop displays
// with no backlight device at all, so ddcutil is the only way in) plus a
// decorative spinner between them. Deliberately not volume: the bar already
// has a pill, a popup and an OSD for that.
//
// One of these is instantiated per screen from shell.qml, the same idiom
// Wallpaper and Bar already use.
PanelWindow {
    id: root

    required property var modelData

    screen: modelData
    readonly property string screenName: root.modelData.name

    // Edge assignment is geometry, not a hardcoded output name: the leftmost
    // screen's outer edge is its left side, the rightmost's is its right.
    // Ties -- a single monitor, which is simultaneously the leftmost and the
    // rightmost thing on the desktop -- resolve to the right edge, per S9. A
    // screen that is neither extreme (a middle monitor in a three-wide row)
    // has no outer edge and gets no panel: `_hasEdge` below zeroes the strip
    // out for it, and everything downstream of that follows for free.
    readonly property real _minX: Math.min(...Quickshell.screens.map(s => s.x))
    readonly property real _maxX: Math.max(...Quickshell.screens.map(s => s.x))
    readonly property bool _isLeftmost: root.modelData.x <= root._minX
    readonly property bool _isRightmost: root.modelData.x >= root._maxX
    readonly property bool _hasEdge: root._isLeftmost || root._isRightmost
    readonly property bool _edgeLeft: root._hasEdge && root._isLeftmost && !root._isRightmost

    readonly property int stripWidth: 6
    // How much of the screen's edge actually triggers the panel, as a share
    // of its height, centred. The full edge was too much of one: the corners
    // of a screen are where a pointer is thrown to reach something else
    // entirely -- a window's close button, the far end of a sweep across two
    // monitors -- and a panel that opens there opens at everything.
    readonly property real stripSpan: 0.36
    // How far left of the card's true centre the controls sit.
    //
    // Everything in this panel is centred to the pixel -- both sliders, both
    // icons, both labels and the art's own box all measure to the same axis
    // as the card's edges. The art does not look like it, because the
    // character is not drawn in the middle of her own canvas: her hair
    // carries the weight to one side. Since she is the largest thing here she
    // is what the eye takes for the middle, so the controls line up with her
    // rather than with the geometry, and the panel reads as straight. This is
    // the one number for that; nothing else here is off-centre by design.
    readonly property int opticalNudge: 2
    // Sized to the widest thing the panel actually has to say -- a slider's
    // "100%" -- plus the padding below, and nothing else. It was 64 with
    // `spaceEdge` on each side, which is a popup's padding on a strip barely
    // wider than one glyph, and the art, being the only child that fills the
    // column, was left looking like the reason for the slack.
    readonly property int panelWidth: 48

    anchors {
        left: root._edgeLeft
        right: !root._edgeLeft
        top: true
        bottom: true
    }
    implicitWidth: root._hasEdge ? root.stripWidth + root.panelWidth : 1
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // A hover affordance, not a dialog -- nothing here is ever worth the
    // keyboard.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Chosen so the lead can add it to the blur layer rule (hyprland.lua)
    // without touching `qs-wallpaper`, which is the wallpaper layer itself
    // and must stay off every blur rule -- see the comment there.
    WlrLayershell.namespace: "qs-edge"
    color: "transparent"

    // Only the strip accepts pointer input while closed; the card, still
    // sitting off the window's own bounds at that point (see panelCard.x
    // below), would contribute nothing to this union even without the
    // `_hasEdge` guard on the strip's own width -- but the guard is what
    // keeps a middle monitor's window fully inert rather than merely empty.
    mask: Region {
        item: stripArea

        Region {
            item: panelCard
            intersection: Intersection.Combine
        }
    }

    // True while the pointer is over the strip or the card -- the two
    // MouseAreas below both feed this, so crossing from one to the other
    // never reads as a gap.
    // A window covering the screen is the one time the pointer reaching the
    // edge is not a request for this panel -- it is someone aiming at a game
    // or a video that happens to end there. Services/Workspaces.qml already
    // works out whether the focused workspace is covered, re-reading the
    // listing rather than trusting the `fullscreen` event, so this asks that
    // rather than deriving a second answer to the same question.
    //
    // Focused, not per-monitor, and that is the right question here: under
    // follow_mouse the monitor whose edge you are touching is the focused one
    // by the time you touch it, so "the workspace you are looking at is
    // covered" and "the workspace this strip belongs to is covered" are the
    // same statement whenever it matters.
    readonly property bool blocked: Workspaces.focusedCovered
    readonly property bool hovering: !root.blocked
        && (stripHover.containsMouse || panelHover.containsMouse)
    property bool _open: false

    onHoveringChanged: {
        if (root.hovering) {
            retractTimer.stop();
            root._open = true;
        } else {
            // A short grace period rather than an instant retract, so a
            // slightly wobbly path from the strip onto a slider -- or
            // across the gap between the two sliders -- does not fold the
            // panel back up mid-reach.
            retractTimer.restart();
        }
    }

    Timer {
        id: retractTimer
        interval: Motion.slow
        onTriggered: root._open = false
    }

    // Local, reactive shadow of the DDC cache. Ddc.brightness()/contrast()
    // read a plain JS object that is mutated in place rather than
    // reassigned, so a QML binding that calls them directly never re-runs on
    // its own -- only the explicit `changed` signal says anything moved.
    // These three properties are what turn that signal back into something
    // the sliders below can bind to normally.
    property bool ddcHas: false
    property int brightnessPct: -1
    property int contrastPct: -1

    function _refreshDdc() {
        root.ddcHas = Ddc.has(root.screenName);
        root.brightnessPct = Ddc.brightness(root.screenName);
        root.contrastPct = Ddc.contrast(root.screenName);
    }

    Connections {
        target: Ddc
        function onReadyChanged() { root._refreshDdc(); }
        function onChanged(screenName) {
            if (screenName === root.screenName) root._refreshDdc();
        }
    }

    Component.onCompleted: root._refreshDdc()

    // The hover trigger. Invisible -- it is a few pixels of otherwise dead
    // screen edge, not a piece of chrome -- flush against the true outer
    // edge on whichever side this screen owns.
    Item {
        id: stripArea

        x: root._hasEdge ? (root._edgeLeft ? 0 : root.width - root.stripWidth) : 0
        // A band across the middle of the edge rather than the whole of it --
        // see stripSpan. Centred on the screen, so it is the same reach on
        // either monitor whatever their heights are.
        y: Math.round((root.height - height) / 2)
        // Zero while a fullscreen window is up, which takes the strip out of
        // the input mask entirely rather than merely ignoring what it reports:
        // a dead 6px column down the side of a game is exactly what this
        // window must not leave behind.
        width: root._hasEdge && !root.blocked ? root.stripWidth : 0
        height: Math.round(root.height * root.stripSpan)

        MouseArea {
            id: stripHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    Rectangle {
        id: panelCard

        // Slides between fully hidden -- off the window's own bounds, so it
        // paints nothing and (per the mask above) accepts nothing -- and
        // resting flush against the strip. The window's own width already
        // equals stripWidth + panelWidth, so "resting" and "the whole
        // window" are the same rectangle; nothing about `_open` ever asks
        // for a mask wider than what is actually on screen.
        readonly property real hiddenX: root._edgeLeft ? -width : root.width
        readonly property real shownX: root._edgeLeft ? root.stripWidth : root.width - root.stripWidth - width

        x: root._open ? shownX : hiddenX
        y: Math.round((root.height - height) / 2)
        width: root.panelWidth
        height: content.implicitHeight + Caelus.spaceEdge * 2

        radius: Caelus.radiusPopover
        color: Colors.popupBg
        border.width: Caelus.borderWidth
        border.color: Colors.popupBorder

        Behavior on x {
            NumberAnimation {
                duration: Motion.base
                easing.type: root._open ? Motion.enter : Motion.exit
            }
        }

        MouseArea {
            id: panelHover
            anchors.fill: parent
            hoverEnabled: true
            // First child, so it stays below the sliders' own MouseAreas
            // and only ever swallows a click that missed them -- the same
            // "catch what falls through, then get out of the way" role
            // BarPopup's and Launcher's card-background MouseAreas play.
        }

        ColumnLayout {
            id: content

            // Centred on the card by anchor and given its width outright,
            // rather than left to `anchors.fill` plus margins. A Layout that
            // is told to fill is still free to lay its own children out
            // against a width it worked out for itself, and the sliders were
            // coming out sitting several pixels left of the card they are in
            // because of exactly that -- which then made the one child that
            // does fill, the art, look like the thing that was off.
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: Caelus.space
            anchors.bottomMargin: Caelus.space
            width: panelCard.width - 2 * Caelus.space
            spacing: Caelus.spaceWide

            // Centred rather than filled. A slider is only as wide as its own
            // widest line -- "100%" -- which is narrower than the column the
            // art fills, and a Layout child that does not fill sits at the
            // start of its column, not the middle of it. That was the whole
            // of the unevenness: the sliders were left-aligned against art
            // that was centred, so the art took the blame for it.
            EdgeSlider {
                Layout.alignment: Qt.AlignHCenter
                // Twice the nudge, because a centred layout child splits the
                // margin it is given: taking `2 * n` off the right moves it
                // `n` to the left.
                Layout.rightMargin: 2 * root.opticalNudge
                Layout.preferredHeight: 120
                visible: root.ddcHas
                icon: "brightness_6"
                value: Math.max(0, root.brightnessPct) / 100
                onMoved: v => Ddc.setBrightness(root.screenName, Math.round(v * 100))
            }

            // The decorative spinner. `assets/edge-art.gif` is a slot rather
            // than a fixed picture: present it when there is a file there,
            // take up no space at all when there is not, so the panel is
            // never holding a gap open for a missing image.
            // Sized to the column rather than to a number of its own, and
            // the slot takes exactly the height that leaves. A fixed 40x40
            // box was both wider than the 36px the card's padding actually
            // leaves -- so the picture alone reached closer to the card's
            // edges than anything else in it, which is what made the panel
            // read as wider than it is -- and squarer than the file, so
            // PreserveAspectFit letterboxed it and the subject sat in a band
            // of empty space it did not need.
            Item {
                id: artSlot

                Layout.fillWidth: true
                Layout.preferredHeight: art.height
                visible: art.status === Image.Ready

                AnimatedImage {
                    id: art

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: artSlot.width
                    // The file's own proportions, so the item is the picture
                    // and there is no fitted-into slack for it to drift
                    // inside. sourceSize is zero until the first frame has
                    // decoded; the slot is hidden until then anyway, and the
                    // square fallback keeps this from dividing by it.
                    height: art.sourceSize.width > 0
                        ? Math.round(art.width * art.sourceSize.height / art.sourceSize.width)
                        : art.width
                    source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/rd-shell/assets/edge-art.gif"
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    cache: false
                }

                // No RotationAnimator over the top. The spin is the file's
                // own -- the gif here animates a turn in place -- and a
                // second rotation applied to the whole frame does not add to
                // that, it tips the already-turning subject over sideways.
                // An asset that does not move on its own is the case that
                // would want one back.
            }

            EdgeSlider {
                Layout.alignment: Qt.AlignHCenter
                Layout.rightMargin: 2 * root.opticalNudge
                Layout.preferredHeight: 120
                visible: root.ddcHas
                icon: "contrast"
                value: Math.max(0, root.contrastPct) / 100
                onMoved: v => Ddc.setContrast(root.screenName, Math.round(v * 100))
            }
        }
    }
}
