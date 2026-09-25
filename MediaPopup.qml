import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.Config
import qs.Services

// Every player that is loaded, not just the one the pill is showing. The pill
// answers "what am I listening to"; this card answers "what else is holding the
// speakers", and lets each of them be started or stopped on its own.
BarPopup {
    id: root

    namespace: "qs-media"
    popupWidth: 320
    popupHeight: body.implicitHeight + 28

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Caelus.spaceEdge
        spacing: Caelus.spaceLoose

        RowLayout {
            Layout.fillWidth: true
            spacing: Caelus.space

            Text {
                text: "queue_music"
                color: Colors.popupAccent
                font.family: Caelus.symbolFamily
                font.pixelSize: 16
            }

            Text {
                text: "Players"
                color: Colors.mediaTitle
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLead
            }

            Item { Layout.fillWidth: true }

            // How many of them are actually sounding, which is the number you
            // opened this card to change.
            Text {
                text: Media.playingCount + " / " + Media.players.length + " playing"
                color: Colors.mediaMeta
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.popupBorder
        }

        Repeater {
            model: Media.players

            Rectangle {
                id: entry

                required property var modelData

                readonly property bool playing: entry.modelData.isPlaying
                readonly property bool controllable: entry.modelData.canTogglePlaying

                // The one row Cava's own reading actually describes: it reads
                // whatever is coming out of the speakers as a whole, gated on
                // `Media.playing` (Cava.qml's own `active`), which is this
                // player and no other. The ring only ever goes on this row.
                readonly property bool isPrimaryPlayer: entry.modelData === Media.player

                // Skipping is shown as a pair or not at all: which way a queue
                // can be walked changes as it is walked, and a button that
                // comes and goes under the cursor is worse than a dim one.
                readonly property bool skippable: entry.modelData.canGoNext || entry.modelData.canGoPrevious
                readonly property bool hasTransport: entry.skippable
                    || entry.modelData.shuffleSupported
                    || entry.modelData.loopSupported

                // Silent players have no stream to turn down, so the slider is
                // only on the rows it can actually move.
                readonly property var stream: Media.streamFor(entry.modelData)
                readonly property bool adjustable: entry.stream?.ready ?? false
                readonly property real volume: entry.stream?.audio?.volume ?? 0
                readonly property bool muted: entry.stream?.audio?.muted ?? false

                // One wheel notch, wherever it is turned over this row.
                function step(angle) {
                    Media.stepVolume(entry.modelData, angle > 0 ? 0.05 : -0.05);
                }

                Layout.fillWidth: true
                implicitHeight: line.implicitHeight + 16
                radius: Caelus.radiusPopover
                color: hover.containsMouse ? Colors.surfaceHover : Colors.mediaCard
                // Only the sounding ones are outlined: with four players loaded
                // the outline is the answer at a glance, before any title is read.
                border.width: 1
                border.color: entry.playing ? Colors.mediaActive : "transparent"

                Behavior on color { ColorAnimation { duration: Motion.fast } }

                MouseArea {
                    id: hover

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    // Left alone even where the player cannot be paused: the
                    // wheel still has something to say about its volume.
                    cursorShape: entry.controllable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    // Middle on a row goes to that player's window, the same as
                    // middle on the pill goes to the one it is showing. The card
                    // goes with it: the focus may land on another workspace, and
                    // an overlay left behind there is over the wrong thing.
                    onClicked: mouse => {
                        if (mouse.button !== Qt.MiddleButton) {
                            Media.toggle(entry.modelData);
                            return;
                        }

                        Media.focusWindow(entry.modelData);
                        root.dismissed();
                    }
                    onWheel: wheel => entry.step(wheel.angleDelta.y)
                }

                RowLayout {
                    id: line

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Caelus.spaceWide
                    anchors.rightMargin: Caelus.spaceLoose
                    spacing: Caelus.spaceLoose

                    Text {
                        visible: !entry.isPrimaryPlayer
                        text: entry.playing ? "graphic_eq" : "music_note"
                        color: entry.playing ? Colors.mediaActive : Colors.mediaMeta
                        font.family: Caelus.symbolFamily
                        font.pixelSize: Caelus.sizeTitle
                    }

                    // 4.3, popup half: circular art with Cava's ring around
                    // it, but only on the one row `isPrimaryPlayer` picks out.
                    // The cell is reserved at the ring's full footprint as
                    // soon as cava could ever have something to draw --
                    // `Cava.available` is fixed for the life of the session,
                    // unlike `active`, which flips on every play and pause --
                    // so starting or stopping this player never changes this
                    // row's width; only the ring inside the reserved space
                    // fades in or out. With cava not installed, `available`
                    // stays false and this cell stays exactly the old glyph's
                    // size, art included.
                    Item {
                        id: artSlot

                        readonly property int ringSize: 44
                        readonly property int compactSize: Caelus.sizeTitle
                        readonly property int cellSize: Cava.available ? artSlot.ringSize : artSlot.compactSize

                        visible: entry.isPrimaryPlayer
                        Layout.preferredWidth: artSlot.cellSize
                        Layout.preferredHeight: artSlot.cellSize
                        Layout.alignment: Qt.AlignVCenter

                        // Only instantiated at all while cava could ever be
                        // active, so a session without the binary never builds
                        // a ring it will never show, on top of the ring's own
                        // `Cava.active` gate inside CavaRing itself.
                        Loader {
                            anchors.centerIn: parent
                            active: Cava.available
                            sourceComponent: CavaRing {
                                diameter: artSlot.ringSize
                                tint: Colors.mediaActive
                            }
                        }

                        MediaArt {
                            anchors.centerIn: parent
                            width: Cava.available ? 22 : artSlot.compactSize
                            height: width
                            source: entry.modelData.trackArtUrl ?? ""
                            fallbackGlyph: entry.playing ? "graphic_eq" : "music_note"
                            glyphColor: entry.playing ? Colors.mediaActive : Colors.mediaMeta
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        // A player with nothing loaded still has a name, and that
                        // name is the only thing worth printing about it.
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.trackTitle !== ""
                                ? entry.modelData.trackTitle
                                : entry.modelData.identity
                            color: Colors.mediaTitle
                            font.family: Caelus.fontFamily
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.trackArtist !== ""
                                ? entry.modelData.identity + "  ·  " + entry.modelData.trackArtist
                                : entry.modelData.identity
                            color: Colors.mediaMeta
                            font.family: Caelus.fontFamily
                            font.pixelSize: Caelus.sizeLabel
                            elide: Text.ElideRight
                            visible: entry.modelData.trackTitle !== ""
                        }

                        // Everything past play and pause, which stays the
                        // circle at the end of the row. A player only gets the
                        // buttons it advertises, so mpv keeps the single line
                        // it always was and Spotify grows the strip it can
                        // actually answer.
                        RowLayout {
                            Layout.topMargin: 3
                            spacing: Caelus.spaceWide
                            visible: entry.hasTransport

                            // Bottom hit margin trimmed to 0 on all four:
                            // this row sits directly above the VolumeSlider
                            // below, and the default -4 left a ~1px band
                            // where both MouseAreas were hit-testable -- see
                            // MediaButton.qml for the full reasoning.
                            MediaButton {
                                text: "shuffle"
                                visible: entry.modelData.shuffleSupported
                                active: entry.modelData.shuffle
                                bottomHitMargin: 0
                                onTriggered: Media.toggleShuffle(entry.modelData)
                            }

                            MediaButton {
                                text: "skip_previous"
                                visible: entry.skippable
                                available: entry.modelData.canGoPrevious
                                bottomHitMargin: 0
                                onTriggered: Media.previous(entry.modelData)
                            }

                            MediaButton {
                                text: "skip_next"
                                visible: entry.skippable
                                available: entry.modelData.canGoNext
                                bottomHitMargin: 0
                                onTriggered: Media.next(entry.modelData)
                            }

                            // One glyph for both kinds of repeat: the bar under
                            // the arrows is what says the whole list, the 1 in
                            // the middle what says this track.
                            MediaButton {
                                text: entry.modelData.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                                visible: entry.modelData.loopSupported
                                active: entry.modelData.loopState !== MprisLoopState.None
                                bottomHitMargin: 0
                                onTriggered: Media.cycleLoop(entry.modelData)
                            }
                        }

                        // This player's own loudness, not the sink's: dragging
                        // it leaves everything else on the machine where it is,
                        // which is the reason to come here rather than to the
                        // volume pill.
                        VolumeSlider {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            visible: entry.adjustable
                            value: entry.volume
                            muted: entry.muted
                            onMoved: v => Media.setVolume(entry.modelData, v)
                            onToggled: Media.toggleMute(entry.modelData)
                            onStepped: delta => entry.step(delta)
                        }
                    }

                    // Reads the row's state and is clicked through to the mouse
                    // area behind it, so the whole row stays one target.
                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        // Without a minimum, a long Spotify title (elide
                        // reports its full preferred width) squeezes this
                        // circle sideways into an oval once the row runs
                        // short of space.
                        Layout.minimumWidth: 30
                        radius: Caelus.radiusPill
                        color: Colors.bg
                        opacity: entry.controllable ? 1 : 0.4

                        Text {
                            anchors.centerIn: parent
                            text: entry.playing ? "pause" : "play_arrow"
                            color: Colors.popupAccent
                            font.family: Caelus.symbolFamily
                            font.pixelSize: Caelus.sizeTitle
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: Caelus.spaceTight
            Layout.bottomMargin: Caelus.spaceTight
            text: "Nothing is loaded"
            color: Colors.mediaMeta
            font.family: Caelus.fontFamily
            font.pixelSize: Caelus.sizeBody
            horizontalAlignment: Text.AlignHCenter
            visible: Media.players.length === 0
        }
    }
}
