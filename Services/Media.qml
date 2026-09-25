pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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

    // Spotify specifically, or null while it is not running -- for
    // DesktopMedia.qml, which follows this and only this, never whichever
    // player `player` above happens to be showing. Matched the same way
    // `streamFor`/`windowFor` already match a player to something else that
    // does not share its identity string outright: `namesFor`'s slugs,
    // checked for "spotify".
    readonly property MprisPlayer spotify: players.find(p => namesFor(p).some(n => n.includes("spotify"))) ?? null

    readonly property bool available: player !== null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""

    readonly property string label: artist !== "" ? `${artist} — ${title}` : title

    // How many are sounding at once, which is the only thing the pill cannot
    // say: it only ever shows one of them.
    readonly property int playingCount: players.filter(p => p.isPlaying).length

    // ── artists ──────────────────────────────────────────────
    // Shared by artistsOf() and titleOf() below so the two can never
    // disagree about which branch produced the features: the title is only
    // ever parsed once, not once per caller.
    function trackInfo(p) {
        if (!p) return { artists: [], title: "" };

        // xesam:artist is a QStringList over the bus -- a plain JS array by
        // the time it crosses into QML through `metadata`, an ordinary
        // QVariantMap -- and the primary source, since most MPRIS players
        // give every featured artist its own entry in it.
        const list = (p.metadata["xesam:artist"] ?? []).filter(a => (a ?? "").trim() !== "");
        if (list.length > 1) return { artists: list, title: p.trackTitle ?? "" };

        // Spotify does not: xesam:artist is a one-element QStringList even on
        // a four-artist track. Its full credit list comes from the track's
        // public page instead (see `_credits` below), once that has been read
        // for this exact track -- and on top of either, whatever a
        // "(feat. ...)" title names that the credits do not already.
        const primary = list[0] ?? p.trackArtist ?? "";
        const parsed = featuredFromTitle(p.trackTitle ?? "");
        const credited = p === root.spotify && root._credits.track === root.spotifyTrackId
            ? root._credits.names : [];
        const base = credited.length > 0 ? credited : (primary !== "" ? [primary] : []);
        const seen = base.map(a => a.toLowerCase());
        const artists = base.concat(parsed.features.filter(f => !seen.includes(f.toLowerCase())));

        return { artists, title: parsed.title };
    }

    // Spotify's current track id, from xesam:url -- "" while none is loaded
    // or the url is anything but an open.spotify.com track (a local file, a
    // podcast episode).
    readonly property string spotifyTrackId:
        /^https:\/\/open\.spotify\.com\/track\/([A-Za-z0-9]+)$/.exec(spotify?.metadata["xesam:url"] ?? "")?.[1] ?? ""

    // Every artist the track is credited to, main artist first, read off the
    // public track page (no login): its embedded initialState JSON names
    // each one separately, which the page's comma-joined meta description
    // cannot do for a name like "Tyler, The Creator". One fetch per track
    // change; a failed or reshaped page just leaves the title fallback above.
    property var _credits: ({ track: "", names: [] })

    onSpotifyTrackIdChanged: _fetchCredits()
    Component.onCompleted: _fetchCredits()

    function _fetchCredits() {
        const id = root.spotifyTrackId;
        if (id === "" || id === creditsProc.track || creditsProc.running) return;
        creditsProc.track = id;
        creditsProc.running = true;
    }

    // Keyed on the track the page itself describes, not on creditsProc.track:
    // a skip mid-fetch re-arms the process for the next track, and nothing
    // guarantees this lands before that happens.
    function _acceptCredits(text) {
        try {
            const items = JSON.parse(text).entities.items;
            const key = Object.keys(items).find(k => k.startsWith("spotify:track:"));
            const t = items[key];
            const names = [...t.firstArtist.items, ...t.otherArtists.items]
                .map(a => a.profile?.name ?? "")
                .filter(n => n !== "");
            if (names.length > 0) root._credits = { track: key.slice(14), names };
        } catch (e) {}
    }

    Process {
        id: creditsProc

        property string track: ""

        // The id goes in as $1, never spliced into the script, and is
        // letters and digits only by `spotifyTrackId`'s own pattern anyway.
        command: ["sh", "-c",
            "curl -sfL --max-time 8 -A Mozilla/5.0 \"https://open.spotify.com/track/$1\" "
            + "| grep -oE 'id=\"initialState\"[^>]*>[^<]+' | sed 's/.*>//' | base64 -d",
            "sh", track]
        stdout: StdioCollector {
            onStreamFinished: root._acceptCredits(this.text)
        }
        // A track change while this was busy was skipped above; catch up.
        onRunningChanged: if (!running) root._fetchCredits()
    }

    // The artist line for a track, main artist first: MPRIS's own list when
    // it has more than one name in it, else the title-parsed fallback --
    // see trackInfo() above.
    function artistsOf(p) {
        return trackInfo(p).artists;
    }

    // The title with a feat. clause stripped, but only the clause
    // artistsOf() actually pulled features from above -- one MPRIS already
    // split into its own artist entry is left in the title exactly as the
    // player sent it, since nothing was taken out of it.
    function titleOf(p) {
        return trackInfo(p).title;
    }

    // Peels a trailing "(feat. ...)" / "(ft. ...)" / "(featuring ...)" /
    // "(with ...)" clause off a track title. Parenthesised or bracketed
    // only -- "Song feat. X" with no bracket at all is rare enough, and
    // ambiguous enough against a title that simply happens to contain the
    // word "with", that it is left alone rather than guessed at.
    function featuredFromTitle(title) {
        const m = /^(.*?)\s*[([]\s*(?:feat\.?|ft\.?|featuring|with)\s+([^)\]]+)[)\]]\s*$/i.exec(title ?? "");
        if (!m) return { title: title ?? "", features: [] };

        const features = m[2]
            .split(/\s*(?:,|&|\band\b)\s*/i)
            .map(s => s.trim())
            .filter(s => s !== "");
        return { title: m[1], features };
    }

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
