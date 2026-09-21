pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris

Singleton {
    id: root

    // playerctld is left out: it is a proxy, not a player. It answers the bus
    // with whatever the last active player said -- Spotify's identity, desktop
    // entry and track, all of it -- so leaving it in listed every real player
    // twice and counted it twice. Told apart by bus name because that is the
    // only thing it does not copy.
    readonly property var players: Mpris.players.values
        .filter(p => !(p.dbusName ?? "").startsWith("org.mpris.MediaPlayer2.playerctld"))

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
    // volume pill. Audio owns PipeWire and its tracker now; Media only matches
    // MPRIS players to the streams Audio already binds.
    readonly property var streams: Audio.sinkStreams

    // The stream carrying a player's sound, or null while it has none: PipeWire
    // drops an application's stream once it stops feeding the graph. Matched by
    // name because a name is all the two sides share -- MPRIS never says which
    // process a player is, and PipeWire never says which bus name a stream
    // answers to -- so both are reduced to letters and digits and compared
    // loosely: "Mozilla Firefox" and the stream called "Firefox" are one player.
    function streamFor(target) {
        const p = target ?? player;
        if (!p) return null;

        const wanted = namesFor(p);

        return streams.find(s => [
            s.name,
            s.properties["application.name"],
            s.properties["application.process.binary"]
        ].map(slug).some(k => k.length >= 3 && wanted.some(n => k.includes(n) || n.includes(k)))) ?? null;
    }

    // Every name a player may be known by away from the bus: what it calls
    // itself, the desktop entry it points at, and the head of its bus name.
    // Both the stream carrying its sound and the window it plays out of are
    // found by these, so they are written down once.
    function namesFor(p) {
        return [
            slug(p.identity),
            slug(p.desktopEntry?.split(".").pop()),
            slug(p.dbusName?.replace("org.mpris.MediaPlayer2.", "").split(".")[0])
        ].filter(n => n.length >= 3);
    }

    // The window the sound is coming out of, or null while there is none: mpd
    // and playerctld answer MPRIS without ever owning one.
    //
    // Matched by app id and by the same names as the stream, because that is
    // what the two sides share. A pid would be exact, but neither side offers
    // one: Hyprland's toplevels carry an empty lastIpcObject until something
    // asks for a refresh, and PipeWire leaves application.process.id unset on
    // plenty of streams, Spotify's included.
    function windowFor(target) {
        const p = target ?? player;
        if (!p) return null;

        const wanted = namesFor(p);
        const candidates = Hyprland.toplevels.values.filter(w => {
            const id = slug(w.wayland?.appId);
            return id.length >= 3 && wanted.some(n => id.includes(n) || n.includes(id));
        });

        // One browser, four windows: the one whose title carries the track is
        // the one playing it.
        const track = slug(p.trackTitle);
        return (track.length >= 3 ? candidates.find(w => slug(w.title).includes(track)) : null)
            ?? candidates[0] ?? null;
    }

    // Middle click, wherever a player is shown on the bar: raise what is making
    // the sound and go to it. A player with no window leaves the click doing
    // nothing rather than moving you somewhere unrelated.
    function focusWindow(target) {
        Workspaces.focusWindow(windowFor(target)?.address ?? "");
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

    // ── transport ────────────────────────────────────────────
    // Everything a player offers past play and pause. Each one is asked for
    // only where the player says it has it, so nothing is sent down the bus
    // that the far end will refuse: Spotify answers all four, mpv on a single
    // file answers none.
    function next(target) {
        const p = target ?? player;
        if (p?.canGoNext) p.next();
    }

    function previous(target) {
        const p = target ?? player;
        if (p?.canGoPrevious) p.previous();
    }

    function toggleShuffle(target) {
        const p = target ?? player;
        if (p?.shuffleSupported) p.shuffle = !p.shuffle;
    }

    // Off, then the whole list, then the one track. The order every player with
    // a repeat button already cycles in, so a click lands where it is expected
    // to rather than where MPRIS happens to list the states.
    function cycleLoop(target) {
        const p = target ?? player;
        if (!p?.loopSupported) return;

        p.loopState = p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
            : p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
            : MprisLoopState.None;
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
