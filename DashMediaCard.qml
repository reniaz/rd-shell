import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services

// The dashboard's now-playing strip. Composed out of the same pieces
// MediaPopup.qml and DesktopMedia.qml already built -- MediaArt for the
// circular art-or-glyph, MediaButton for transport -- rather than a third
// copy of either; nothing in this file draws a button or a circle of its
// own. Deliberately just the one primary player (Media.player, whichever is
// actually making sound), not MediaPopup's full per-player list: the
// dashboard is a glance, not the mixer.
Rectangle {
    id: root

    readonly property var player: Media.player

    Layout.fillWidth: true
    implicitHeight: 72
    radius: Caelus.radiusCard
    color: Colors.calField
    border.width: 1
    border.color: Colors.calFieldBorder

    RowLayout {
        anchors.fill: parent
        anchors.margins: Caelus.space
        spacing: Caelus.space

        MediaArt {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            source: root.player?.trackArtUrl ?? ""
            fallbackGlyph: root.player?.isPlaying ? "graphic_eq" : "music_note"
            glyphColor: root.player?.isPlaying ? Colors.mediaActive : Colors.mediaMeta
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.player !== null
                    ? (Media.titleOf(root.player) !== "" ? Media.titleOf(root.player) : root.player.identity)
                    : "Nothing playing"
                color: Colors.mediaTitle
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeBody
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.player !== null && root.player.trackArtist !== ""
                text: root.player?.trackArtist ?? ""
                color: Colors.mediaMeta
                font.family: Caelus.fontFamily
                font.pixelSize: Caelus.sizeLabel
                elide: Text.ElideRight
            }
        }

        RowLayout {
            visible: root.player !== null
            spacing: Caelus.spaceSnug

            MediaButton {
                text: "skip_previous"
                available: root.player?.canGoPrevious ?? false
                bottomHitMargin: 0
                onTriggered: Media.previous(root.player)
            }

            MediaButton {
                text: root.player?.isPlaying ? "pause" : "play_arrow"
                active: root.player?.isPlaying ?? false
                bottomHitMargin: 0
                onTriggered: Media.toggle(root.player)
            }

            MediaButton {
                text: "skip_next"
                available: root.player?.canGoNext ?? false
                bottomHitMargin: 0
                onTriggered: Media.next(root.player)
            }
        }
    }
}
