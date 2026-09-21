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

    // A transport control: the bare glyph this bar uses for a button, with a
    // hit area wider than the letter it draws. Colour is the whole readout --
    // lit while what it names is on, greyed while the player cannot answer it
    // yet, as Spotify does with previous at the head of a queue.
    component TransportButton: Text {
        id: button

        property bool active: false
        property bool available: true

        signal triggered()

        color: button.active ? Colors.mediaActive
            : point.hovered ? Colors.mediaTitle
            : Colors.mediaMeta
        opacity: button.available ? 1 : 0.35
        font.family: "Material Symbols Rounded"
        font.pixelSize: 17

        Behavior on color { ColorAnimation { duration: 120 } }

        MouseArea {
            id: press

            anchors.fill: parent
            anchors.margins: -4
            // Trimmed back to 0 on the bottom: this row sits directly above
            // the per-player VolumeSlider, whose track grab area (topMargin
            // -8 in VolumeSlider.qml) already reaches up past its own
            // visual top. Leaving this margin at -4 too left a ~1px band
            // where both MouseAreas were hit-testable, and the slider wins
            // it (declared later), turning a click meant for a button into
            // an absolute volume jump.
            anchors.bottomMargin: 0
            cursorShape: Qt.PointingHandCursor
            // Stays enabled even when the glyph is dim: an `enabled: false`
            // MouseArea does not consume the press at all, so it would fall
            // through to the row-wide `hover` MouseArea behind it and
            // toggle play/pause instead of doing nothing.
            onClicked: {
                if (button.available)
                    button.triggered();
            }
        }

        // The glyph's own hover state comes from a handler rather than from
        // `hoverEnabled` on the MouseArea above. A hovering MouseArea is the
        // end of the line for a hover event: the row-wide MouseArea painted
        // beneath this one would lose `containsMouse` the moment the cursor
        // touched a glyph, so the whole card animated out of its hover fill
        // and back again four times as you crossed the transport strip.
        // HoverHandler reports the same thing without swallowing it.
        HoverHandler {
            id: point
        }
    }

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "queue_music"
                color: Colors.popupAccent
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
            }

            Text {
                text: "Players"
                color: Colors.mediaTitle
                font.family: "caelusevka"
                font.pixelSize: 15
            }

            Item { Layout.fillWidth: true }

            // How many of them are actually sounding, which is the number you
            // opened this card to change.
            Text {
                text: Media.playingCount + " / " + Media.players.length + " playing"
                color: Colors.mediaMeta
                font.family: "caelusevka"
                font.pixelSize: 13
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
                radius: 12
                color: hover.containsMouse ? Colors.surfaceHover : Colors.mediaCard
                // Only the sounding ones are outlined: with four players loaded
                // the outline is the answer at a glance, before any title is read.
                border.width: 1
                border.color: entry.playing ? Colors.mediaActive : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }

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
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: entry.playing ? "graphic_eq" : "music_note"
                        color: entry.playing ? Colors.mediaActive : Colors.mediaMeta
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
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
                            font.family: "caelusevka"
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.trackArtist !== ""
                                ? entry.modelData.identity + "  ·  " + entry.modelData.trackArtist
                                : entry.modelData.identity
                            color: Colors.mediaMeta
                            font.family: "caelusevka"
                            font.pixelSize: 12
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
                            spacing: 12
                            visible: entry.hasTransport

                            TransportButton {
                                text: "shuffle"
                                visible: entry.modelData.shuffleSupported
                                active: entry.modelData.shuffle
                                onTriggered: Media.toggleShuffle(entry.modelData)
                            }

                            TransportButton {
                                text: "skip_previous"
                                visible: entry.skippable
                                available: entry.modelData.canGoPrevious
                                onTriggered: Media.previous(entry.modelData)
                            }

                            TransportButton {
                                text: "skip_next"
                                visible: entry.skippable
                                available: entry.modelData.canGoNext
                                onTriggered: Media.next(entry.modelData)
                            }

                            // One glyph for both kinds of repeat: the bar under
                            // the arrows is what says the whole list, the 1 in
                            // the middle what says this track.
                            TransportButton {
                                text: entry.modelData.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                                visible: entry.modelData.loopSupported
                                active: entry.modelData.loopState !== MprisLoopState.None
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
                        radius: height / 2
                        color: Colors.bg
                        opacity: entry.controllable ? 1 : 0.4

                        Text {
                            anchors.centerIn: parent
                            text: entry.playing ? "pause" : "play_arrow"
                            color: Colors.popupAccent
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 18
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            text: "Nothing is loaded"
            color: Colors.mediaMeta
            font.family: "caelusevka"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            visible: Media.players.length === 0
        }
    }
}
