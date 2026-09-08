pragma Singleton
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values

    // Whatever is playing wins; otherwise fall back to a paused player that
    // still has a track loaded.
    readonly property MprisPlayer player: players.find(p => p.isPlaying)
        ?? players.find(p => p.trackTitle !== "")
        ?? null

    readonly property bool available: player !== null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""

    readonly property string label: artist !== "" ? `${artist} — ${title}` : title

    function toggle() {
        if (player?.canTogglePlaying) player.togglePlaying();
    }
}
