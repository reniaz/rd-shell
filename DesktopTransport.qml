import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.Config
import qs.Services

// The now-playing card's transport row: shuffle / previous / play-pause /
// next / loop, with MediaVolume overlaid at the right end instead of taking
// a sixth slot in the row. Split out of DesktopMedia.qml (contract Round 5)
// so this choreography -- buttons fading out from underneath a slider that
// grows over them -- lives in one file instead of being re-solved by every
// caller that wants a transport strip with an inline volume control.
//
// An Item, not a RowLayout: MediaVolume overlays this row rather than
// taking its own slot in it, so the row's own width has to stay independent
// of whether the volume control is expanded -- a RowLayout has no way to
// hold one child out of its own width calculation like that, a plain Item
// positioning two children by anchors does. `expandedWidth: root.width`
// below is what lets MediaVolume grow all the way across without this Item
// ever changing its own width for it -- the card never resizes for volume.
Item {
    id: root

    // The MprisPlayer every glyph acts on -- DesktopMedia passes
    // Media.spotify, same as every Media.* call below takes it as the
    // explicit target rather than falling back to Media.player.
    property var player: null

    implicitHeight: Math.max(buttons.implicitHeight, volume.implicitHeight)
    // No implicitWidth of its own, unlike MediaVolume's collapsed/expanded
    // pair: this row has nothing to compute a natural width from -- it is
    // handed one, by the caller's `Layout.fillWidth: true` (see the
    // contract) or, in a harness, by anchors. `volume`'s `expandedWidth:
    // root.width` below is what actually needs that width to be current.

    RowLayout {
        id: buttons

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Caelus.space
        // Faded out and disabled while the volume control has grown over
        // them, not just dimmed: `opacity` alone never stops a click from
        // landing underneath whatever is drawn on top of it in Qt Quick, the
        // same caveat MediaButton.qml's own bottomHitMargin comment and
        // MediaVolume.qml's collapsed-glyph MouseArea both already have to
        // work around.
        opacity: volume.expanded ? 0 : 1
        enabled: !volume.expanded

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.fast
                easing.type: volume.expanded ? Motion.exit : Motion.standard
            }
        }

        // 16px rather than MediaButton's 17 on every glyph in this row: the
        // desktop card was shrunk well below the popup's size on purpose,
        // and a point smaller keeps the row inside its narrower width with
        // the play/pause disc still reading as the one primary control.
        MediaButton {
            text: "shuffle"
            font.pixelSize: 16
            visible: root.player?.shuffleSupported ?? false
            active: root.player?.shuffle ?? false
            onTriggered: Media.toggleShuffle(root.player)
        }

        MediaButton {
            text: "skip_previous"
            font.pixelSize: 16
            visible: (root.player?.canGoPrevious || root.player?.canGoNext) ?? false
            available: root.player?.canGoPrevious ?? false
            onTriggered: Media.previous(root.player)
        }

        // The primary control: a tonal fill rather than MediaPopup's flat
        // Colors.bg circle -- solid black read as heavy against this card's
        // translucent body once it grew to "primary" size. Reuses the same
        // accent-disc-plus-on-accent-glyph pairing calToday/calTodayFg
        // already gives the calendar's filled "today" marker, the one other
        // place this shell paints a solid accent disc with text on top,
        // rather than re-deriving light-or-dark-glyph correctness here.
        Rectangle {
            id: playPause

            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: Caelus.radiusPill
            color: Colors.mediaActive
            opacity: (root.player?.canTogglePlaying ?? false) ? 1 : 0.4

            Text {
                anchors.centerIn: parent
                text: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow"
                color: Colors.calTodayFg
                font.family: Caelus.symbolFamily
                font.pixelSize: 16
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.toggle(root.player)
            }
        }

        MediaButton {
            text: "skip_next"
            font.pixelSize: 16
            visible: (root.player?.canGoPrevious || root.player?.canGoNext) ?? false
            available: root.player?.canGoNext ?? false
            onTriggered: Media.next(root.player)
        }

        MediaButton {
            text: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
            font.pixelSize: 16
            visible: root.player?.loopSupported ?? false
            active: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
            onTriggered: Media.cycleLoop(root.player)
        }
    }

    // Anchored to this row's own right edge, on top of `buttons` rather than
    // after it: expanding grows this leftwards over the buttons (which fade
    // out above) instead of pushing the card's own edge outward the way an
    // earlier version of this card did.
    MediaVolume {
        id: volume

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        player: root.player
        // The row's own full width -- fixed, since this component never
        // changes size for the volume control -- so expanding reaches
        // exactly as far as `buttons` itself spans, never short of the
        // shuffle glyph, never past it either.
        expandedWidth: root.width
    }

    // What the card's own wheel handler calls on every notch turned
    // anywhere over it, not just over `volume` itself -- same idiom
    // MediaVolume's own `poke()` doc comment describes, one level up.
    function pokeVolume() {
        volume.poke();
    }
}
