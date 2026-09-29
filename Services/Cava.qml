pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// Live spectrums read from cava's own 'raw' output mode -- twelve numbers a
// frame, streamed on a pipe -- in two feeds (Services/CavaFeed.qml):
//
//   - `islands`: every playback stream but wayvibes' key clicks -- Spotify,
//     Firefox, a game, whatever is sounding. The bar strip, the media
//     popup's ring and the workspace beat glow read this one.
//   - `desktop`: the desktop Spotify card's. Spotify alone while Spotify is
//     playing, even with other apps sounding over it; otherwise the same
//     everything-but-wayvibes mix as `islands` -- so it simply *is*
//     `islands` then, rather than a second cava hearing the same streams.
//
// A feed only runs while one of its streams is actually sounding: a stream
// counts as sounding while PipeWire has one of its links Active, which is
// exactly what a paused player's corked stream stops being (checked with
// pw-dump: paused Firefox's links read `paused`, playing Spotify's and a
// running game's `active`).
//
// cava has to be told its settings through a config file; there is no flag
// for bar count or output format. That file is written here, at
// ~/.cache/rd-shell/cava.conf, rather than shipped as a dotfile under
// ~/.config/cava: Services/Wallpapers.qml already treats ~/.cache/rd-shell as
// this shell's own cache directory, and a config this file writes itself on
// every start is one a stale hand-edit can never survive to break the parser.
// Both feeds read the same file, so both hear with the same sensitivity.
//
// Every detail of the config below was checked against the cava actually
// installed on this machine (0.10.2, `rpm -q cava`):
//   - this build links libpulse and libasound but not libpipewire
//     (`ldd /usr/bin/cava`), so `method = pipewire` fails outright.
//     `method = pulse` works: PipeWire's pulse-compatible server answers it.
//   - raw_target = /dev/stdout needs no fifo of its own: cava only creates a
//     fifo when its target does not already exist, and /dev/stdout always
//     does.
//   - a captured run (`cava -p <this config>` piped to a file) confirmed the
//     frame shape CavaFeed's `_parse` checks for: `bars` ascii integers
//     0-100, EACH followed by ';' -- including the last -- then '\n'.
Singleton {
    id: root

    readonly property int bars: 12

    // cava's own emitted rate, shared with every envelope follower that
    // converts Motion's millisecond durations into a frame count.
    readonly property int framerate: 30

    readonly property CavaFeed islands: islandsFeed
    readonly property CavaFeed desktop: root._spotifySounding ? spotifyFeed : islandsFeed

    // Latched per feed on its first successful spawn -- see CavaFeed's
    // `everRan` -- so MediaPopup can reserve the ring's cell off it without
    // the row resizing on every play and pause.
    readonly property bool available: islandsFeed.everRan || spotifyFeed.everRan

    function _names(s) {
        return [
            s.name,
            s.properties["application.name"],
            s.properties["application.process.binary"]
        ].map(Media.slug);
    }

    // Every playback stream but wayvibes, matched on any of its names so a
    // renamed node still cannot slip its key clicks into the spectrum.
    readonly property var _mix: Audio.sinkStreams.filter(s => !root._names(s).some(k => k.includes("wayvibes")))

    // Spotify's own playback stream(s), matched the same loose way
    // `Media.streamFor` matches a player to its stream: `Media.namesFor`'s
    // slugs against the stream's names, either side `includes` the other.
    // `.filter`, not `.find`: every stream Spotify opens belongs in the mix.
    readonly property var _spotifyStreams: {
        const spotify = Media.spotify;
        if (!spotify) return [];
        const wanted = Media.namesFor(spotify);
        return Audio.sinkStreams.filter(s => root._names(s)
            .some(k => k.length >= 3 && wanted.some(n => k.includes(n) || n.includes(k))));
    }

    function _sounding(s) {
        return Pipewire.linkGroups.values.some(g => g.source === s && g.state === PwLinkState.Active);
    }

    // A link group only reports its state once bound; unbound it reads
    // Unlinked no matter what flows through it.
    PwObjectTracker {
        objects: Pipewire.linkGroups.values.filter(g => root._mix.includes(g.source))
    }

    readonly property bool _mixSounding: root._mix.some(root._sounding)
    readonly property bool _spotifySounding: root._spotifyStreams.some(root._sounding)

    readonly property string _configPath: `${Quickshell.env("HOME")}/.cache/rd-shell/cava.conf`

    property bool _configReady: false

    readonly property string _config:
        "[general]\n" +
        "bars = " + root.bars + "\n" +
        // A twelve-bar mini meter loses nothing visible between 60fps and 30.
        "framerate = " + root.framerate + "\n" +
        // Two seconds of true silence -- a gap between tracks, a game gone
        // quiet -- and cava stops running FFT and redraw until sound returns.
        "sleep_timer = 2\n" +
        "\n" +
        "[input]\n" +
        "method = pulse\n" +
        "\n" +
        "[output]\n" +
        "method = raw\n" +
        "raw_target = /dev/stdout\n" +
        // One spectrum, low to high -- the flat `levels` array CavaFeed
        // promises. 'stereo' would mirror two spectrums into the same count.
        "channels = mono\n" +
        "data_format = ascii\n" +
        "ascii_max_range = 100\n" +
        "bar_delimiter = 59\n" +
        "frame_delimiter = 10\n";

    Component.onCompleted: configFile.setText(root._config)

    FileView {
        id: configFile
        path: root._configPath
        // Write-only: a read preload on a cold start just logs "File does
        // not exist" before the write below has had a chance to run.
        preload: false
        onSaved: root._configReady = true
        // Left false on failure: with no valid config, `available` staying
        // false reads to every caller exactly like cava being absent.
        onSaveFailed: error => root._configReady = false
    }

    CavaFeed {
        id: islandsFeed
        nodeName: "rd-cava"
        configPath: root._configPath
        configReady: root._configReady
        bars: root.bars
        framerate: root.framerate
        streams: root._mix
        wanted: root._mixSounding
    }

    CavaFeed {
        id: spotifyFeed
        nodeName: "rd-spotify-cava"
        configPath: root._configPath
        configReady: root._configReady
        bars: root.bars
        framerate: root.framerate
        streams: root._spotifyStreams
        wanted: root._spotifySounding
    }
}
