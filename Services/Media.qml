pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

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

    // How many are sounding at once, which is the only thing the pill cannot
    // say: it only ever shows one of them.
    readonly property int playingCount: players.filter(p => p.isPlaying).length

    // ── volume ───────────────────────────────────────────────
    // Every application playback stream. A player's own volume lives here and
    // not on MPRIS: Firefox reports 100% over the bus while its stream sits at
    // 84%, and plenty of players never implement the bus property at all.
    // Turning one of these down leaves the sink -- and so every other player --
    // where it was, which is the whole point of asking here rather than at the
    // volume pill.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink)

    // Volume is only readable and writable on a bound node.
    PwObjectTracker { objects: root.streams }

    // The stream carrying a player's sound, or null while it has none: PipeWire
    // drops an application's stream once it stops feeding the graph. Matched by
    // name because a name is all the two sides share -- MPRIS never says which
    // process a player is, and PipeWire never says which bus name a stream
    // answers to -- so both are reduced to letters and digits and compared
    // loosely: "Mozilla Firefox" and the stream called "Firefox" are one player.
    function streamFor(target) {
        const p = target ?? player;
        if (!p) return null;

        const wanted = [
            slug(p.identity),
            slug(p.desktopEntry?.split(".").pop()),
            slug(p.dbusName?.replace("org.mpris.MediaPlayer2.", "").split(".")[0])
        ].filter(n => n.length >= 3);

        return streams.find(s => [
            s.name,
            s.properties["application.name"],
            s.properties["application.process.binary"]
        ].map(slug).some(k => k.length >= 3 && wanted.some(n => k.includes(n) || n.includes(k)))) ?? null;
    }

    function volumeOf(target) {
        return streamFor(target)?.audio?.volume ?? 0;
    }

    function setVolume(target, v) {
        const audio = streamFor(target)?.audio;
        if (audio) audio.volume = Math.max(0, Math.min(1, v));
    }

    // What a wheel notch is worth, wherever one is turned over a player.
    function stepVolume(target, delta) {
        setVolume(target, volumeOf(target) + delta);
    }

    function toggleMute(target) {
        const audio = streamFor(target)?.audio;
        if (audio) audio.muted = !audio.muted;
    }

    function slug(text) {
        return (text ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    // Defaults to the player the pill is showing, so the bar's click is
    // unchanged; the popup passes the row that was clicked instead.
    function toggle(target) {
        const p = target ?? player;
        if (p?.canTogglePlaying) p.togglePlaying();
    }
}
