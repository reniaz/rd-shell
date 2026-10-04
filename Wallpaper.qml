import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Services
import qs.Config

// Quickshell draws the desktop wallpaper itself, on its own background layer,
// so it can own the swap animation. swaybg only ever pops instantly and swww
// would pull in a system dependency the user does not want -- "only my
// quickshell" is the standing constraint on this file. One of these is
// instantiated per screen from shell.qml, the same way Bar is.
PanelWindow {
    id: root

    required property var modelData

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-wallpaper"
    // Only ever seen for a frame at startup before the first decode lands, or
    // through the gap the sourceSize-driven decode leaves at a resize.
    color: "#000000"

    // This sits behind every other surface already, but wlroots still asks
    // each layer what it wants for input, and an unset mask defaults to the
    // whole surface being solid. A wallpaper must never be the thing a click
    // lands on, so the region handed over is permanently empty.
    mask: emptyRegion
    Region { id: emptyRegion }

    // Two Images ping-pong roles rather than one Image being re-sourced in
    // place: `back` decodes the next wallpaper off-screen (opacity 0) while
    // `front` keeps showing the current one at full opacity, so there is
    // never a frame where neither holds a picture and the bare `color` above
    // shows through.
    property bool aIsFront: true
    readonly property Image front: root.aIsFront ? imgA : imgB
    readonly property Image back: root.aIsFront ? imgB : imgA

    // Flips true the first time a wallpaper actually lands. Checked so the
    // very first image of a session is placed directly instead of animating
    // in -- there is nothing on screen yet to transition from, and animating
    // it anyway would just read as a slow-starting shell.
    property bool haveShown: false

    // The swap is a masked reveal: the incoming wallpaper is already fully
    // drawn and at full opacity from the first frame, and what grows is the
    // hole it is seen through, until it has covered everything. The old
    // wallpaper sits underneath the whole time and is only dropped once the
    // hole has passed the far corner, so the two genuinely overlap rather
    // than cross-fading through a washed-out middle.
    //
    // A cross-fade was the first attempt and looked wrong for the same reason
    // it always does: for a third of a second the desktop is two pictures at
    // half strength and neither of them is the wallpaper.
    //
    // The hole's shape is one of Wallpapers.transitions -- a circle opening
    // from a corner or the centre ("grow"), a ring closing in on the centre
    // ("outer"), a straight or rippling edge sweeping across at an angle
    // ("wipe"/"wave"). Copied off the service when a swap starts rather than
    // bound to it, so a pick arriving mid-reveal cannot change the shape of
    // the one already playing.
    property Image revealing: null
    property real revealProgress: 0
    property string revealKind: "grow"
    property real revealSeed: 0

    readonly property real _diag: Math.sqrt(root.width * root.width + root.height * root.height)

    // grow: one of the four corners or the centre, by seed. The circle has
    // to reach the farthest screen corner from wherever it starts, so that
    // distance is its final radius. outer: always the centre, so the ring
    // closes on the middle of the screen from a circle that just covers it.
    readonly property point _growOrigin: {
        const i = Math.floor(root.revealSeed * 5);
        if (root.revealKind !== "grow" || i === 4) return Qt.point(root.width / 2, root.height / 2);
        return Qt.point(i % 2 ? root.width : 0, i < 2 ? 0 : root.height);
    }
    readonly property real _growReach: {
        const o = root._growOrigin;
        return Math.sqrt(Math.max(o.x, root.width - o.x) ** 2 + Math.max(o.y, root.height - o.y) ** 2);
    }
    readonly property real _circleSize: root.revealKind === "outer"
        ? (1 - root.revealProgress) * root._diag
        : root.revealProgress * 2 * root._growReach

    // wipe/wave: drawn in a square one screen-diagonal wide, centred and
    // rotated by seed -- whatever the angle, that square covers the whole
    // screen and its left edge lies wholly off it, so the edge sweeping
    // from that side to the other starts unseen and ends with nothing left
    // uncovered. A wipe is a wave with no amplitude; the ripple travels
    // along the edge as it sweeps rather than standing still.
    readonly property real _waveAmp: root.revealKind === "wave" ? root._diag * 0.03 : 0
    readonly property var _edgePoints: {
        if (root.revealKind !== "wipe" && root.revealKind !== "wave") return [];
        const d = root._diag, a = root._waveAmp;
        const lambda = d / 4;
        const phase = root.revealProgress * Math.PI * 3;
        const base = root.revealProgress * (d + 2 * a) - a;
        // Left of the furthest the edge ever swings back, so the polygon
        // never folds over itself at the start of the sweep.
        const left = -2 * a - 1;
        const pts = [Qt.point(left, 0)];
        const steps = a > 0 ? 96 : 1;
        for (let i = 0; i <= steps; i++) {
            const y = d * i / steps;
            pts.push(Qt.point(base + a * Math.sin(2 * Math.PI * y / lambda + phase), y));
        }
        pts.push(Qt.point(left, d));
        return pts;
    }

    Image {
        id: imgA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // These are 4-18MP source files; the Qt pixmap cache is not the place
        // for a whole wallpaper tree, and only one of the two ever needs to
        // be resident at a time anyway.
        cache: false
        // Pinned to the window's own (unanimated) geometry rather than to
        // anything the enter animation touches -- sourceSize is part of the
        // decode cache key, so a value riding a running animation would
        // re-decode the JPEG on every frame instead of once.
        sourceSize: Qt.size(root.width, root.height)
        opacity: 1

        // The arriving wallpaper has to be the one on top, or the circle
        // uncovers it underneath a sibling that is still fully opaque and
        // nothing appears until the animation ends and that sibling is
        // switched off -- a wait the length of the reveal followed by an
        // instant cut. The two images swap roles on every wallpaper, so
        // declaration order alone got this right exactly half the time,
        // which is what made it look intermittent.
        z: root.revealing === imgA ? 1 : 0

        // The mask is only in the way while this one is arriving. Off the
        // rest of the time, the image draws straight to the screen with no
        // layer texture standing between it and the compositor.
        layer.enabled: root.revealing === imgA
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: revealShape
            // The mask is drawn hard-edged in white on nothing, so the
            // threshold sits in the middle of that step and the narrow
            // spread either side of it is what keeps the growing rim from
            // being a visibly jagged circle.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.04
            // "outer" draws the circle the old wallpaper is still seen
            // through, not the new one -- the arriving image shows
            // everywhere outside it.
            maskInverted: root.revealKind === "outer"
        }

        onStatusChanged: if (status === Image.Ready || status === Image.Error) root._onIncomingStatus(imgA)
    }

    Image {
        id: imgB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(root.width, root.height)
        opacity: 0

        // The arriving wallpaper has to be the one on top, or the circle
        // uncovers it underneath a sibling that is still fully opaque and
        // nothing appears until the animation ends and that sibling is
        // switched off -- a wait the length of the reveal followed by an
        // instant cut. The two images swap roles on every wallpaper, so
        // declaration order alone got this right exactly half the time,
        // which is what made it look intermittent.
        z: root.revealing === imgB ? 1 : 0

        // The mask is only in the way while this one is arriving. Off the
        // rest of the time, the image draws straight to the screen with no
        // layer texture standing between it and the compositor.
        layer.enabled: root.revealing === imgB
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: revealShape
            // The mask is drawn hard-edged in white on nothing, so the
            // threshold sits in the middle of that step and the narrow
            // spread either side of it is what keeps the growing rim from
            // being a visibly jagged circle.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.04
            // "outer" draws the circle the old wallpaper is still seen
            // through, not the new one -- the arriving image shows
            // everywhere outside it.
            maskInverted: root.revealKind === "outer"
        }

        onStatusChanged: if (status === Image.Ready || status === Image.Error) root._onIncomingStatus(imgB)
    }

    function _loadCurrent() {
        if (!Wallpapers.current) return;

        // A wallpaper can be picked again while the previous swap is still
        // revealing. `front`/`back` are roles computed from `aIsFront`, and
        // that only flips once revealAnim finishes -- so without this, the
        // Image currently on screen mid-reveal (still `back` until the flip)
        // would have its `source` pulled out from under it by this call
        // instead of by the fresh pick about to be applied to it. Stopping
        // the animation runs its onStopped synchronously, which does the
        // flip and drops the mask right away, so an interrupted reveal reads
        // as an instant cut to where it was headed, and `root.back` below is
        // then the correct, uninvolved Image.
        if (revealAnim.running) revealAnim.stop();

        const url = "file://" + Wallpapers.current;

        // `Image.source` is a `url`-typed property, which QML hands back to
        // JavaScript as a QUrl-wrapped object rather than a plain string --
        // it prints identically to `url` in a template literal (both call
        // toString()), but `===` against the string never matched, silently
        // defeating both guards below. `.toString()` on both sides of every
        // comparison here gets an actual string comparison.
        const frontUrl = root.front.source.toString();
        const backUrl = root.back.source.toString();

        // Already what's on screen: nothing to swap to.
        if (frontUrl === url) return;

        if (backUrl === url) {
            // Same string this Image already held: Qt's property system
            // treats the assignment below as a no-op, so neither
            // sourceChanged nor statusChanged fires and _incomingReady would
            // never run on its own. This is what re-picking a wallpaper --
            // or landing back on one still held from a couple of swaps ago
            // -- looked like before: a click that visibly did nothing. If
            // the decode already finished, kick the reveal directly; if it
            // is still in flight, or failed, the status-change handler below
            // still covers it once that resolves.
            if (root.back.status === Image.Ready) root._incomingReady(root.back);
            return;
        }

        root.back.source = url;
    }

    // Single handler for both Images rather than duplicating the same
    // Ready/Error logic twice: each Image only calls this for the two
    // statuses that matter (its onStatusChanged guards that, the same way
    // the original single-purpose handler did) and only acts when it is the
    // one currently playing the `back` role, since the other one settling
    // mid-decode of a since-abandoned source is not this swap's concern.
    function _onIncomingStatus(img) {
        if (root.back !== img) return;

        if (img.status === Image.Ready) {
            root._incomingReady(img);
        } else {
            // The only other status this is ever called for is Image.Error.
            // wallpaper-apply.sh already resolved this path to a real file
            // on disk, but Qt could not decode it -- wrong format, a
            // truncated write, whatever. There is nothing to reveal, and the
            // old wallpaper is still showing (it was never touched), so the
            // desktop itself is fine; what needs fixing is `source` itself.
            // Left alone, it would sit there holding the exact string that
            // just failed, and the same-source guard above would treat a
            // retry of this exact path -- the user picking it again after
            // fixing the file -- as another no-op rather than a fresh
            // decode attempt.
            console.warn("Wallpaper: failed to decode " + img.source);
            img.source = "";
        }
    }

    // Wait for the decode rather than reacting to sourceChanged: the incoming
    // Image is asynchronous and these files are large enough that starting
    // the fade the moment `source` is set would run it against a blank item
    // for however long the decode actually takes.
    function _incomingReady(incoming) {
        if (!root.haveShown) {
            incoming.opacity = 1;
            root.front.opacity = 0;
            root.aIsFront = !root.aIsFront;
            root.haveShown = true;
            return;
        }

        // _loadCurrent() above always settles a reveal already in flight
        // before choosing `incoming`, so revealAnim is guaranteed idle here
        // -- restart() below never fights a running animation over
        // `outgoing` or the aIsFront flip it does in onStopped.

        // Full opacity from the start -- the mask, not the alpha, is what
        // decides how much of it you can see.
        root.revealKind = Wallpapers.transition;
        root.revealSeed = Wallpapers.transitionSeed;
        root.revealProgress = 0;
        root.revealing = incoming;
        incoming.opacity = 1;
        revealAnim.outgoing = root.front;
        revealAnim.restart();
    }

    // The shape the reveal is seen through. Drawn white on nothing, taken as
    // a texture rather than rendered to the screen, and grown by the animation
    // below; MultiEffect keeps whichever wallpaper is arriving only where this
    // is opaque.
    Item {
        id: revealShape

        anchors.fill: parent
        // Rendered into a texture and never onto the desktop. `opacity: 0`
        // rather than `visible: false` on purpose: a layer is drawn from the
        // item's contents and the item's own opacity is applied afterwards,
        // when the layer is composited -- so this keeps producing a live
        // texture for the mask while contributing nothing to the screen,
        // which an invisible item would not.
        opacity: 0
        layer.enabled: true

        Rectangle {
            visible: root.revealKind === "grow" || root.revealKind === "outer"
            width: root._circleSize
            height: width
            radius: width / 2
            x: root._growOrigin.x - width / 2
            y: root._growOrigin.y - width / 2
            color: "#ffffff"
        }

        Item {
            visible: root._edgePoints.length > 0
            anchors.centerIn: parent
            width: root._diag
            height: root._diag
            rotation: root.revealSeed * 360

            Shape {
                anchors.fill: parent
                // Antialiased edge: the geometry renderer would hand the
                // mask a stair-stepped rim, which a rotated edge shows far
                // more than the circle ever did.
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "#ffffff"
                    strokeColor: "transparent"
                    fillRule: ShapePath.WindingFill
                    PathPolyline { path: root._edgePoints }
                }
            }
        }
    }

    NumberAnimation {
        id: revealAnim

        property Item outgoing: null

        target: root
        property: "revealProgress"
        from: 0
        to: 1
        // Long enough to read as a sweep rather than a cut, short enough that
        // picking wallpapers in a row does not feel like waiting on each one.
        duration: Motion.reveal
        easing.type: Motion.standard

        // Only now is the old wallpaper let go: until the mask has covered
        // the whole screen it is still what fills everything the mask has
        // not reached yet.
        onStopped: {
            revealAnim.outgoing.opacity = 0;
            root.aIsFront = !root.aIsFront;
            root.revealing = null;
            root.revealProgress = 0;
        }
    }

    Connections {
        target: Wallpapers
        function onCurrentChanged() { root._loadCurrent(); }
    }

    Component.onCompleted: root._loadCurrent()
}
